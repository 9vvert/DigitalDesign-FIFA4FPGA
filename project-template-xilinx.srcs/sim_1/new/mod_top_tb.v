`timescale 1ns/1ps
module mod_top_tb();

    reg clock;
    reg reset;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, mod_top_tb);
        clock = 1'b0;
        reset = 1'b0;

        #100;
        reset = 1'b1;

        #100;
        reset = 1'b0;

        #50000;
        $finish;
    end

    always #5 clock = ~clock; // 100MHz


    video u_video800x600at72 (
    .clk(clock)
    );

    // mod_top dut(
    //     .clk_100m(clock),
    //     .btn_rst(reset)
    // );

endmodule
