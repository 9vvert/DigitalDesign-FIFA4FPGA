`timescale 1ns / 1ps

module ps2_clk;

    // 仿真时钟和复位信号
    wire pmod1_io1;    // PMOD 接口引脚 1
    wire pmod1_io2;    // PMOD 接口引脚 2
    wire pmod1_io3;    // PMOD 接口引脚 3
    wire pmod1_io4;    // PMOD 接口引脚 4
    reg clk_100m;      // 100MHz 输入时钟
    reg btn_rst;       // 复位信号，低电平有效

    // 模块实例的输出信号
    wire ps2_clk;      // 10MHz PS2 时钟信号

    wire clk_in = clk_100m;

    // PLL 分频演示，从输入产生不同频率的时钟
    wire clk_hdmi;
    wire clk_locked;
    ip_pll u_ip_pll(
        .clk_in1  (clk_in    ),  // 输入 100MHz 时钟
        .reset    (rst_sync   ),  // 复位信号，高有效
        .clk_out1 (clk_hdmi  ),  // 50MHz 像素时钟
        .clk_out2 (ps2_clk   ),  // 10MHz PS2 时钟
        .locked   (clk_locked)   // 高表示 50MHz 时钟已经稳定输出
    );

    // 输入信号初始化
    initial begin
        clk_100m = 0;   // 初始时钟为 0
        btn_rst = 1;    // 初始复位信号为高（复位）
        #50;            // 保持复位信号 50ns
        btn_rst = 0;    // 取消复位
    end
    reg [1:0] rst_sync;
    wire rst_synced;

    // use rst_synced as asynchronous reset of all modules
    assign rst_synced = rst_sync[1];

    always @(posedge clk_100m, posedge btn_rst) begin
        if (btn_rst) begin
            rst_sync <= 2'b11;
        end else begin
            rst_sync <= {rst_sync[0], btn_rst};
        end
    end
    // 生成 100MHz 时钟（周期为 10ns）
    always #5 clk_100m = ~clk_100m;

    // 实例化被测模块（UUT）
    mod_top uut (
        .clk_100m(clk_100m), // 100MHz 时钟输入
        .btn_clk(1'b0),      // 不使用手动时钟
        .btn_rst(rst_sync),   // 复位信号
        .btn_push(4'b0),     // 不使用按键
        .dip_sw(16'b0),      // 不使用拨码开关
        .led_bit(),          // 不关心 LED 输出
        .led_com(),          // 不关心 LED 扫描信号
        .dpy_digit(),        // 不关心数码管输出
        .dpy_segment(),      // 不关心数码管扫描信号
        .hdmi_tmds_n(),      // 不关心 HDMI 输出
        .hdmi_tmds_p(),
        .hdmi_tmds_c_n(),
        .hdmi_tmds_c_p()
    );
    ps2_new u_ps2(
        .ps2_clk(ps2_clk),    // 10MHz PS2 时钟输出
        .rst(rst_sync),       // 复位信号
        .pmod_io1(pmod1_io1), // MOSI
        .pmod_io2(pmod1_io2), // MISO
        .pmod_io3(pmod1_io3), // SCLK
        .pmod_io4(pmod1_io4)  // CS
    );


    // 仿真观察
    initial begin
        // 运行仿真一段时间

        #10000000000;
        
        $display("Simulation completed.");
        $stop;
    end

endmodule