`timescale 1ns / 1ps
module test_cmd(
    // 时钟
    input  wire clk_100m,           // 100M 输入时钟

    // 开关
    input  wire btn_clk,            // 左侧微动开关（CLK），推荐作为手动时钟，带消抖电路，按下时为 1
    input  wire btn_rst,            // 右侧微动开关（RST），推荐作为手动复位，带消抖电路，按下时为 1
    input  wire [3:0]  btn_push,    // 四个按钮开关（KEY1-4），按下时为 1
    input  wire [15:0] dip_sw,      // 16 位拨码开关，拨到 “ON” 时为 0

    // 数码管，配合 dpy_scan 模块使用
    output wire [7:0] dpy_digit,   // 七段数码管笔段信号
    output wire [7:0] dpy_segment, // 七段数码管位扫描信号

        //PMOD引脚
    output wire pmod1_io1,    // PMOD 接口引脚 1
    input wire pmod1_io2,    // PMOD 接口引脚 2
    output wire pmod1_io3,    // PMOD 接口引脚 3
    output wire pmod1_io4    // PMOD 接口引脚 4

    );

    // 使用 100MHz 时钟作为后续逻辑的时钟
    wire clk_in = clk_100m;

    // PLL 分频演示，从输入产生不同频率的时钟
    
    wire clk_ddr;
    wire clk_ref;
    wire clk_locked;
    ip_pll u_ip_pll(
        .clk_in1  (clk_in    ),  // 输入 100MHz 时钟
        .reset    (btn_rst   ),  // 复位信号，高有效
        // .clk_out1 (clk_hdmi  ),  // 50MHz 像素时钟
        .clk_out2 (clk_ref   ),  // 200MHz DDR 参考时钟
        .clk_out3 (clk_ddr   ),  // 400MHz DDR 控制器时钟
        .locked   (clk_locked)   // 高表示 50MHz 时钟已经稳定输出
    );
    wire clk_hdmi;
    wire hdmi_locked;
    clk_wiz_0 u_clk_wiz_0 (
        .clk_in1(clk_in),         // 100MHz 输入时钟
        .clk_out1(clk_hdmi),      // 50MHz 输出时钟
        .reset(btn_rst),          // 复位信号
        .locked(hdmi_locked)       // 锁定信号
    );

    // 七段数码管扫描演示
    wire [31:0] number;
    dpy_scan u_dpy_scan (
        .clk     (clk_in      ),
        .number  (number      ),
        .dp      (8'b0        ),

        .digit   (dpy_digit   ),
        .segment (dpy_segment )
    );

    wire rst;
    reg [1:0] rst_reg;
    always @(posedge clk_100m) begin
        rst_reg[0] <= btn_rst;           // 第一级寄存器，同步输入
        rst_reg[1] <= rst_reg[0];        // 第二级寄存器，消除亚稳态
    end
    assign rst = rst_reg[1];
    
    /*************  时钟生成  ****************/
    wire ui_clk;
    wire ui_rst;
    assign ui_clk = clk_100m;
    assign ui_rst = rst;
    reg ps2_clk;
    reg [9:0] ps2_clk_cnt;
    always @(posedge ui_clk) begin      // 使用ui_clk生成game_clk和ps2_clk，更加稳定
        if(ui_rst) begin
            ps2_clk <= 1'b0;
            ps2_clk_cnt <= 10'b0;
        end else begin
            if(ps2_clk_cnt == 10'd499) begin    // 500次反转，意味着频率是原来的1/1000，也就是100kHz (10us一次)
                ps2_clk <= ~ps2_clk; // 反转时钟
                ps2_clk_cnt <= 10'b0;
            end else begin
                ps2_clk_cnt <= ps2_clk_cnt + 10'b1;
            end
        end
    end

    // 生成game_clk的初始值
    //[TODO]迁移到game_top.sv
    reg game_clk;
    reg game_rst;      // ui_rst可能因为时间过短，无法支持ps2_clk和game_clk的初始化
    reg [31:0] game_rst_counter;
    reg [31:0] game_clk_cnt;
    // 为了仿真，将间隔调小
    always @(posedge ui_clk) begin
        if(ui_rst) begin
            game_clk <= 0;
            game_clk_cnt <= 0;
            game_rst <= 0;
            game_rst_counter <= 0;
        end else begin
            if(game_clk_cnt == 49999) begin    //(1ms一次)
                game_clk <= ~game_clk; // 反转时钟
                game_clk_cnt <= 0;
            end else begin
                game_clk_cnt <= game_clk_cnt + 1;
            end
            //让game_rst持续若干周期，保证能够初始化
            if(game_rst_counter == 499999)begin
                game_rst <= 1;
                game_rst_counter <= game_rst_counter + 1;
            end else if(game_rst_counter == 999999)begin
                game_rst <= 0;
                //这种情况下千万不要再递增game_rst_counter, 否则会周期性复位
            end else begin
                game_rst_counter <= game_rst_counter + 1;
            end
        end
    end

    wire [7:0] cmd_left_angle;
    wire [7:0] cmd_right_angle;
    wire [7:0] cmd_action_cmd;
    cmd_decoder u_cmd_decoder(
        .game_clk(game_clk),
        .ps2_clk(ps2_clk),
        .rst(game_rst),
        .pmod_io1(pmod1_io1),
        .pmod_io2(pmod1_io2),
        .pmod_io3(pmod1_io3),
        .pmod_io4(pmod1_io4),
        .left_angle(cmd_left_angle), 
        .right_angle(cmd_right_angle),
        .action_cmd2(cmd_action_cmd)        //已经完成消抖
    );
    assign number[7:0] = cmd_action_cmd;
    assign number[15:8] = cmd_left_angle;
    assign number[23:16] = cmd_right_angle;

endmodule
