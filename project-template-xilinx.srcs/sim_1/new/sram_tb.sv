`timescale 1ns / 1ps

module sram_tb;

    reg clk;
    reg rst;
    initial begin
        clk = 0;
        #100;
        rst = 0;
        #100;
        rst = 1;
        #100;
        rst = 0;
    end
    test_sram u_test_sram(
        .clk_100m(clk),
        .btn_rst(rst)
    );
    always #5 clk = ~clk;


endmodule