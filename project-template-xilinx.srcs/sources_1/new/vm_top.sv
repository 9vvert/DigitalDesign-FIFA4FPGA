`timescale 1ns / 1ps
module vm_top(
    // 时钟
    input  wire clk_100m,           // 100M 输入时钟

    // 开关
    input  wire btn_clk,            // 左侧微动开关（CLK），推荐作为手动时钟，带消抖电路，按下时为 1
    input  wire btn_rst,            // 右侧微动开关（RST），推荐作为手动复位，带消抖电路，按下时为 1
    input  wire [3:0]  btn_push,    // 四个按钮开关（KEY1-4），按下时为 1
    input  wire [15:0] dip_sw,      // 16 位拨码开关，拨到 “ON” 时为 0

    // 32 位 LED 灯，配合 led_scan 模块使用
    output wire [7:0] led_bit,      // 8 位 LED 信号
    output wire [3:0] led_com,      // LED 扫描信号，每一位对应 8 位的 LED 信号

    // 数码管，配合 dpy_scan 模块使用
    output wire [7:0] dpy_digit,   // 七段数码管笔段信号
    output wire [7:0] dpy_segment, // 七段数码管位扫描信号

    // 以下是一些被注释掉的外设接口
    // 若要使用，不要忘记去掉 io.xdc 中对应行的注释

    // PS/2 键盘
    // input  wire        ps2_keyboard_clk,     // PS/2 键盘时钟信号
    // input  wire        ps2_keyboard_data,    // PS/2 键盘数据信号

    // PS/2 鼠标
    // inout  wire       ps2_mouse_clk,     // PS/2 时钟信号
    // inout  wire       ps2_mouse_data,    // PS/2 数据信号

    //SD 卡（SPI 模式）
    output wire        sd_sclk,     // SPI 时钟
    output wire        sd_mosi,     // 数据输出
    input  wire        sd_miso,     // 数据输入
    output wire        sd_cs,       // SPI 片选，低有效
    input  wire        sd_cd,       // 卡插入检测，0 表示有卡插入
    input  wire        sd_wp,       // 写保护检测，0 表示写保护状态

    // RGMII 以太网接口
    // output wire        rgmii_clk125,
    // input  wire        rgmii_rx_clk,
    // input  wire        rgmii_rx_ctl,
    // input  wire [3: 0] rgmii_rx_data,
    // output wire        rgmii_tx_clk,
    // output wire        rgmii_tx_ctl,
    // output wire [3: 0] rgmii_tx_data,

    // 4MB SRAM 内存
    inout  wire [31:0] base_ram_data,   // SRAM 数据
    output wire [19:0] base_ram_addr,   // SRAM 地址
    output wire [3: 0] base_ram_be_n,   // SRAM 字节使能，低有效。如果不使用字节使能，请保持为0
    output wire        base_ram_ce_n,   // SRAM 片选，低有效
    output wire        base_ram_oe_n,   // SRAM 读使能，低有效
    output wire        base_ram_we_n,   // SRAM 写使能，低有效

    // 512MB DDR3 SDRAM 内存
    inout  wire [7 :0] ddr3_dq,
    inout  wire [0 :0] ddr3_dqs_n,
    inout  wire [0 :0] ddr3_dqs_p,
    output wire [15:0] ddr3_addr,
    output wire [2 :0] ddr3_ba,
    output wire        ddr3_ras_n,
    output wire        ddr3_cas_n,
    output wire        ddr3_we_n,
    output wire        ddr3_reset_n,
    output wire [0 :0] ddr3_ck_p,
    output wire [0 :0] ddr3_ck_n,
    output wire [0 :0] ddr3_cke,
    output wire [0 :0] ddr3_cs_n,
    output wire [0 :0] ddr3_dm,
    output wire [0 :0] ddr3_odt,

    // HDMI 图像输出
    output wire [2:0] hdmi_tmds_n,    // HDMI TMDS 数据信号
    output wire [2:0] hdmi_tmds_p,    // HDMI TMDS 数据信号
    output wire       hdmi_tmds_c_n,  // HDMI TMDS 时钟信号
    output wire       hdmi_tmds_c_p   // HDMI TMDS 时钟信号

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
    reg [31:0] number;
    dpy_scan u_dpy_scan (
        .clk     (clk_in      ),
        .number  (number      ),
        .dp      (8'b0        ),

        .digit   (dpy_digit   ),
        .segment (dpy_segment )
    );

    // // 自增计数器，用于数码管演示
    // reg [31:0] counter;
    // always @(posedge clk_in) begin
    //     if (btn_rst) begin
    //         counter <= 32'b0;
    //         number <= 32'b0;
    //     end else begin
    //         counter <= counter + 32'b1;
    //         if (counter == 32'd5_000_000) begin
    //             counter <= 32'b0;
    //             number <= number + 32'b1;
    //         end
    //     end
    // end

    // LED 演示
    wire [31:0] leds;
    assign leds[15:0] = number[15:0];
    assign leds[31:16] = ~(dip_sw) ^ btn_push;
    led_scan u_led_scan (
        .clk     (clk_in      ),
        .leds    (leds        ),

        .led_bit (led_bit     ),
        .led_com (led_com     )
    );
    wire rst;
    reg [1:0] rst_reg;
    always @(posedge clk_100m) begin
        rst_reg[0] <= btn_rst;           // 第一级寄存器，同步输入
        rst_reg[1] <= rst_reg[0];        // 第二级寄存器，消除亚稳态
    end
    assign rst = rst_reg[1];

    /***********  渲染 *************/
    wire ui_clk;
    wire [31:0] write_data;
    wire [14:0] write_addr;
    wire write_enable;
    wire batch_free;                // 请求batch 的信号
    wire batch_zero;
    wire dark_begin;
    wire dark_end;
    wire light_begin;
    wire light_end;
    reg [11:0] y_pos[1:0];
    Render_Param_t in_render_param[1:0]; 

    always @(posedge clk_100m) begin
        if(rst)begin
            y_pos[0] = 20;
            in_render_param[0] = '{render_type:1, hpos: 64, vpos:128, angle: 0, stat: 1, width: 32, height:32};
            y_pos[1] = 10;
            in_render_param[1] = '{render_type:2, hpos: 128, vpos:64, angle: 0, stat: 2, width: 32, height:32};
        end
    end

    vm_manager u_vm_manager
    (
        .debug_number(number),
        .clk_100m(clk_100m),       // 100MHz
        .rst(rst),
        .clk_locked(clk_locked),     // 复位信号
        .clk_ddr(clk_ddr),       // 400MHz
        .clk_ref(clk_ref),       // 200MHz
        //SD接口
        .sd_sclk(sd_sclk),     // SPI 时钟
        .sd_mosi(sd_mosi),     // 数据输出
        .sd_miso(sd_miso),     // 数据输入
        .sd_cs(sd_cs),       // SPI 片选，低有效
        .sd_cd(sd_cd),       // 卡插入检测，0 表示有卡插入
        .sd_wp(sd_wp),       // 写保护检测，0 表示写保护状态
        //SDRAM接口
        .ddr3_dq(ddr3_dq),
        .ddr3_dqs_n(ddr3_dqs_n),
        .ddr3_dqs_p(ddr3_dqs_p),
        .ddr3_addr(ddr3_addr),
        .ddr3_ba(ddr3_ba),
        .ddr3_ras_n(ddr3_ras_n),
        .ddr3_cas_n(ddr3_cas_n),
        .ddr3_we_n(ddr3_we_n),
        .ddr3_reset_n(ddr3_reset_n),
        .ddr3_ck_p(ddr3_ck_p),
        .ddr3_ck_n(ddr3_ck_n),
        .ddr3_cke(ddr3_cke),
        .ddr3_cs_n(ddr3_cs_n),
        .ddr3_dm(ddr3_dm),
        .ddr3_odt(ddr3_odt),
        //SRAM接口
        .base_ram_data(base_ram_data),
        .base_ram_addr(base_ram_addr),
        .base_ram_be_n(base_ram_be_n),
        .base_ram_ce_n(base_ram_ce_n),
        .base_ram_oe_n(base_ram_oe_n),
        .base_ram_we_n(base_ram_we_n),
        //数据，和game.sv对接 [TODO]
        .y_pos(y_pos),           //用y值来判断渲染顺序
        .in_render_param(in_render_param),          //具体参数，用来表示渲染的位置，以及采用什么图片素材
        //和video.sv对接的信号
        .batch_free(batch_free),       // 当RAM进行一轮交换后，会发送这个信号，并持续相当长一段周期，保证能够接受到
                                // 这个信号仅仅是用来切换到switcher
        .batch_zero(batch_zero),
        .light_begin(light_begin),
        .light_end(light_end),
        .dark_begin(dark_begin),
        .dark_end(dark_end),
        //[TODO]检查和switch中的宽度是否一致，以及在空闲时候，switch输出的值是否会干扰正常逻辑
        .write_data(write_data),   //[TODO]研究SRAM的字节序，注意进行顺序变换
        .write_addr(write_addr),   //每一个batch，write_addr都是从0开始逐渐增减，在video.sv中会再进行一轮变换
        .write_enable(write_enable),        //写入显存的使能信号
        .out_ui_clk(ui_clk)
    );

    

    // 图像输出演示，分辨率 800x600@72Hz，像素时钟为 50MHz，显示渐变色彩条
    wire [11:0] hdata;  // 当前横坐标
    wire [11:0] vdata;  // 当前纵坐标
    wire [7:0] video_red; // 红色分量
    wire [7:0] video_green; // 绿色分量
    wire [7:0] video_blue; // 蓝色分量
    wire video_clk; // 像素时钟
    wire video_hsync;
    wire video_vsync;
    wire video_de; // 数据使能信号

    // 生成彩条数据，分别取坐标低位作为 RGB 值
    // 警告：该图像生成方式仅供演示，请勿使用横纵坐标驱动大量逻辑！！
     
    // 注意：如果在video中进行了red、green、blue的赋值，那么这里就不能再对video_red,video_green、video_blue进行赋值了
    // 否则会导致时序错误，综合不通过

    assign video_clk = clk_hdmi;
    video u_video
    (
        .ui_clk(ui_clk),
        .fill_batch(batch_free),
        .zero_batch(batch_zero),
        .dark_end(dark_end),
        .light_end(light_end),
        .dark_begin(dark_begin),
        .light_begin(light_begin),
        .write_data(write_data),
        .write_addr(write_addr),
        .write_enable(write_enable),
        .clk(video_clk),
        .hsync(video_hsync),
        .vsync(video_vsync),
        .hdata(hdata),
        .vdata(vdata),
        .red(video_red),         // output reg是时序逻辑，output wire是组合逻辑
        .green(video_green),
        .blue(video_blue),
        .data_enable(video_de)
    );

    // 把 RGB 转化为 HDMI TMDS 信号并输出
    ip_rgb2dvi u_ip_rgb2dvi (
        .PixelClk   (video_clk),
        .vid_pVDE   (video_de),
        .vid_pHSync (video_hsync),
        .vid_pVSync (video_vsync),
        .vid_pData  ({video_red, video_blue, video_green}),
        // .vid_pData  ({read_R, read_B, read_G}),
        .aRst       (~hdmi_locked),

        .TMDS_Clk_p  (hdmi_tmds_c_p),
        .TMDS_Clk_n  (hdmi_tmds_c_n),
        .TMDS_Data_p (hdmi_tmds_p),
        .TMDS_Data_n (hdmi_tmds_n)
    );

endmodule
