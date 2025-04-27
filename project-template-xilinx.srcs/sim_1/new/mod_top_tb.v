`timescale 1ns/1ps
module mod_top_tb();

    reg clock;
    reg reset;

    ip_pll u_ip_pll(
        .clk_in1  (clk_in    ),  // 输入 100MHz 时钟
        .reset    (btn_rst   ),  // 复位信号，高有效
        .clk_out1 (clk_hdmi  ),  // 50MHz 像素时钟
        .clk_out2 (ps2_clk   ),  // 10MHz PS2 时钟
        .locked   (clk_locked)   // 高表示 50MHz 时钟已经稳定输出
    );

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

    mod_top dut(
        .clk_100m(clock),
        .btn_rst(reset)
    );

endmodule
