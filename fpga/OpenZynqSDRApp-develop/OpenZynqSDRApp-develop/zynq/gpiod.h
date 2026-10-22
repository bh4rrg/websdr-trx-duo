// libgpiod v1 API 的最小兼容层（仅实现 OpenZynqSDRApp 用到的函数）
// 直接通过 Linux GPIO chardev v1 ABI (GPIO_GET_LINEHANDLE_IOCTL) 实现，
// 避免依赖 libgpiod（Alpine 3.20 提供的是不兼容的 v2 API）。
#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#define GPIOD_MAX_LINES 64

struct gpiod_chip {
    int fd;
};

struct gpiod_line {
    unsigned int offset;
    struct gpiod_chip *chip;
    int handle_fd;
};

struct gpiod_line_bulk {
    unsigned int num_lines;
    struct gpiod_line lines[GPIOD_MAX_LINES];
    int handle_fd;
};

struct gpiod_chip *gpiod_chip_open(const char *path);
void gpiod_chip_close(struct gpiod_chip *chip);

struct gpiod_line *gpiod_chip_get_line(struct gpiod_chip *chip, unsigned int offset);
int gpiod_chip_get_lines(struct gpiod_chip *chip, unsigned int *offsets,
                         unsigned int num_lines, struct gpiod_line_bulk *bulk);

int gpiod_line_request_output(struct gpiod_line *line, const char *consumer,
                              int default_val);
int gpiod_line_request_bulk_output(struct gpiod_line_bulk *bulk,
                                   const char *consumer, const int *default_vals);

int gpiod_line_set_value(struct gpiod_line *line, int value);
int gpiod_line_set_value_bulk(struct gpiod_line_bulk *bulk, const int *values);

void gpiod_line_release(struct gpiod_line *line);
void gpiod_line_release_bulk(struct gpiod_line_bulk *bulk);

#ifdef __cplusplus
}
#endif
