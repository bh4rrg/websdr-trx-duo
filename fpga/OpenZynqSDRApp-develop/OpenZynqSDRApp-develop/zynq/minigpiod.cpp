// libgpiod v1 API 最小兼容实现 — 基于 GPIO chardev v1 ABI
#include "gpiod.h"

#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <linux/gpio.h>

static void fill_consumer(char *dst, const char *src)
{
    if (src) {
        strncpy(dst, src, 31);
        dst[31] = '\0';
    } else {
        dst[0] = '\0';
    }
}

struct gpiod_chip *gpiod_chip_open(const char *path)
{
    int fd = open(path, O_RDWR | O_CLOEXEC);
    if (fd < 0)
        fd = open(path, O_RDONLY | O_CLOEXEC);
    if (fd < 0)
        return NULL;
    struct gpiod_chip *chip = (struct gpiod_chip *)malloc(sizeof(struct gpiod_chip));
    chip->fd = fd;
    return chip;
}

void gpiod_chip_close(struct gpiod_chip *chip)
{
    if (!chip) return;
    close(chip->fd);
    free(chip);
}

struct gpiod_line *gpiod_chip_get_line(struct gpiod_chip *chip, unsigned int offset)
{
    if (!chip) return NULL;
    struct gpiod_line *line = (struct gpiod_line *)malloc(sizeof(struct gpiod_line));
    line->offset = offset;
    line->chip = chip;
    line->handle_fd = -1;
    return line;
}

int gpiod_chip_get_lines(struct gpiod_chip *chip, unsigned int *offsets,
                         unsigned int num_lines, struct gpiod_line_bulk *bulk)
{
    if (!chip || !bulk || num_lines > GPIOD_MAX_LINES) return -1;
    bulk->num_lines = num_lines;
    bulk->handle_fd = -1;
    for (unsigned int i = 0; i < num_lines; i++) {
        bulk->lines[i].offset = offsets[i];
        bulk->lines[i].chip = chip;
        bulk->lines[i].handle_fd = -1;
    }
    return 0;
}

int gpiod_line_request_output(struct gpiod_line *line, const char *consumer,
                              int default_val)
{
    if (!line || !line->chip) return -1;
    struct gpiohandle_request req;
    memset(&req, 0, sizeof(req));
    req.lineoffsets[0] = line->offset;
    req.flags = GPIOHANDLE_REQUEST_OUTPUT;
    req.default_values[0] = default_val ? 1 : 0;
    fill_consumer((char *)req.consumer_label, consumer);
    req.lines = 1;
    if (ioctl(line->chip->fd, GPIO_GET_LINEHANDLE_IOCTL, &req) < 0)
        return -1;
    line->handle_fd = req.fd;
    return 0;
}

int gpiod_line_request_bulk_output(struct gpiod_line_bulk *bulk,
                                   const char *consumer, const int *default_vals)
{
    if (!bulk || bulk->num_lines == 0) return -1;
    struct gpiod_chip *chip = bulk->lines[0].chip;
    if (!chip) return -1;
    struct gpiohandle_request req;
    memset(&req, 0, sizeof(req));
    for (unsigned int i = 0; i < bulk->num_lines; i++) {
        req.lineoffsets[i] = bulk->lines[i].offset;
        req.default_values[i] = (default_vals && default_vals[i]) ? 1 : 0;
    }
    req.flags = GPIOHANDLE_REQUEST_OUTPUT;
    fill_consumer((char *)req.consumer_label, consumer);
    req.lines = bulk->num_lines;
    if (ioctl(chip->fd, GPIO_GET_LINEHANDLE_IOCTL, &req) < 0)
        return -1;
    bulk->handle_fd = req.fd;
    return 0;
}

int gpiod_line_set_value(struct gpiod_line *line, int value)
{
    if (!line || line->handle_fd < 0) return -1;
    struct gpiohandle_data data;
    memset(&data, 0, sizeof(data));
    data.values[0] = value ? 1 : 0;
    return ioctl(line->handle_fd, GPIOHANDLE_SET_LINE_VALUES_IOCTL, &data);
}

int gpiod_line_set_value_bulk(struct gpiod_line_bulk *bulk, const int *values)
{
    if (!bulk || bulk->handle_fd < 0) return -1;
    struct gpiohandle_data data;
    memset(&data, 0, sizeof(data));
    for (unsigned int i = 0; i < bulk->num_lines; i++)
        data.values[i] = values[i] ? 1 : 0;
    return ioctl(bulk->handle_fd, GPIOHANDLE_SET_LINE_VALUES_IOCTL, &data);
}

void gpiod_line_release(struct gpiod_line *line)
{
    if (!line) return;
    if (line->handle_fd >= 0) {
        close(line->handle_fd);
        line->handle_fd = -1;
    }
    free(line);
}

void gpiod_line_release_bulk(struct gpiod_line_bulk *bulk)
{
    if (!bulk) return;
    if (bulk->handle_fd >= 0) {
        close(bulk->handle_fd);
        bulk->handle_fd = -1;
    }
    bulk->num_lines = 0;
}
