`timescale 1ns / 1ps



module adc_ovr_detect(
    input wire clk_main,
    input wire rst_n,
    
    input wire signed [13:0] adc_data_in,
    input wire ofl_i,
    
    output wire led_n
);

//ADC bus is 14bit here (TRX DUO, 16bit ADC, bits [15:2] used)

wire signed [13:0] adc_abs;//abs value
reg adc_ovr_instant;

reg [22:0] led_counter;

reg led_reg;

assign led_n = ~led_reg;

assign adc_abs = adc_data_in[13] ? -adc_data_in : adc_data_in;

always @(posedge clk_main)
begin
  if(rst_n == 1'd0)
    adc_ovr_instant <= 1'd0;
  else
  begin
    if ((adc_abs > 14'd16300) || ofl_i)
        adc_ovr_instant <= 1'd1;
    else
        adc_ovr_instant <= 1'd0;
    end
end

always @(posedge clk_main)
begin
    if(rst_n == 1'd0)
    begin
        led_counter <= 23'd8000000;
        led_reg <= 1'd0;
    end
    else
    begin
        if (adc_ovr_instant)
        begin
            led_counter <= 23'd0; // Reset counter on over_threshold
            led_reg <= 1'd1;//LED on
        end
        else
        begin
        if (led_counter < 23'd8000000)
            led_counter <= led_counter + 1;
        else
            led_reg <= 1'd0;//LED off
        end
    end
end

endmodule
