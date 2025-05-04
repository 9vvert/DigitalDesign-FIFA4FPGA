`timescale 1ns / 1ps
module mod_top(
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

    output wire pmod1_io1,    // PMOD 接口引脚 1
    input wire pmod1_io2,    // PMOD 接口引脚 2
    output wire pmod1_io3,    // PMOD 接口引脚 3
    output wire pmod1_io4,    // PMOD 接口引脚 4
    // 以下是一些被注释掉的外设接口
    // 若要使用，不要忘记去掉 io.xdc 中对应行的注释

    // PS/2 键盘
    // input  wire        ps2_keyboard_clk,     // PS/2 键盘时钟信号
    // input  wire        ps2_keyboard_data,    // PS/2 键盘数据信号

    // PS/2 鼠标
    // inout  wire       ps2_mouse_clk,     // PS/2 时钟信号
    // inout  wire       ps2_mouse_data,    // PS/2 数据信号

    // SD 卡（SPI 模式）
    // output wire        sd_sclk,     // SPI 时钟
    // output wire        sd_mosi,     // 数据输出
    // input  wire        sd_miso,     // 数据输入
    // output wire        sd_cs,       // SPI 片选，低有效
    // input  wire        sd_cd,       // 卡插入检测，0 表示有卡插入
    // input  wire        sd_wp,       // 写保护检测，0 表示写保护状态

    // RGMII 以太网接口
    // output wire        rgmii_clk125,
    // input  wire        rgmii_rx_clk,
    // input  wire        rgmii_rx_ctl,
    // input  wire [3: 0] rgmii_rx_data,
    // output wire        rgmii_tx_clk,
    // output wire        rgmii_tx_ctl,
    // output wire [3: 0] rgmii_tx_data,

    // 4MB SRAM 内存
    // inout  wire [31:0] base_ram_data,   // SRAM 数据
    // output wire [19:0] base_ram_addr,   // SRAM 地址
    // output wire [3: 0] base_ram_be_n,   // SRAM 字节使能，低有效。如果不使用字节使能，请保持为0
    // output wire        base_ram_ce_n,   // SRAM 片选，低有效
    // output wire        base_ram_oe_n,   // SRAM 读使能，低有效
    // output wire        base_ram_we_n,   // SRAM 写使能，低有效

    // HDMI 图像输出
    output wire [2:0] hdmi_tmds_n,    // HDMI TMDS 数据信号
    output wire [2:0] hdmi_tmds_p,    // HDMI TMDS 数据信号
    output wire       hdmi_tmds_c_n,  // HDMI TMDS 时钟信号
    output wire       hdmi_tmds_c_p   // HDMI TMDS 时钟信号

    );

    // 使用 100MHz 时钟作为后续逻辑的时钟
    wire clk_in = clk_100m;


    reg [1:0] rst_sync;
    wire rst_synced;

    // use rst_synced as asynchronous reset of all modules
    // 复位信号同步逻辑
    assign rst_synced = rst_sync[1];

    always @(posedge clk_100m, posedge btn_rst) begin
        if (btn_rst) begin
            rst_sync <= 2'b11;
        end else begin
            rst_sync <= {rst_sync[0], btn_rst};
        end
    end


    // PLL 分频演示，从输入产生不同频率的时钟
    wire clk_hdmi;
    wire clk_10m; // 10MHz
    wire clk_locked;
    ip_pll u_ip_pll(
        .clk_in1  (clk_in    ),  // 输入 100MHz 时钟
        .reset    (rst_sync   ),  // 复位信号，高有效
        .clk_out1 (clk_hdmi  ),  // 50MHz 像素时钟
        .clk_out2 (clk_10m   ),  // 10MHz PS2 时钟
        .locked   (clk_locked)   // 高表示 50MHz 时钟已经稳定输出
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

    // 自增计数器，用于数码管演示
    // reg [31:0] counter;
    // always @(posedge clk_in) begin
    //     if (rst_sync) begin
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

    // 图像输出演示，分辨率 800x600@72Hz，像素时钟为 50MHz，显示渐变色彩条
    wire [11:0] hdata;  // 当前横坐标
    wire [11:0] vdata;  // 当前纵坐标
    wire [7:0] video_red; // 红色分量
    wire [7:0] video_green; // 绿色分量
    wire [7:0] video_blue; // 蓝色分量
    wire video_clk; // 像素时钟
    wire video_hsync;
    wire video_vsync;

    // 生成彩条数据，分别取坐标低位作为 RGB 值
    // 警告：该图像生成方式仅供演示，请勿使用横纵坐标驱动大量逻辑！！
    
    // 注意：如果在video中进行了red、green、blue的赋值，那么这里就不能再对video_red,video_green、video_blue进行赋值了
    // 否则会导致时序错误，综合不通过

    

    reg ps2_clk;
    reg [9:0] ps2_clk_cnt;
    always @(posedge clk_100m) begin
        if(rst_sync) begin
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

    reg [7:0] ps2_mode;
    reg [7:0] btn_grp1;
    reg [7:0] btn_grp2;
    reg [7:0] rhandle_X;
    reg [7:0] rhandle_Y;
    reg [7:0] lhandle_X;
    reg [7:0] lhandle_Y;
    reg ready; 

    ps2 u_ps2(
        // .debug_number(number),
        .ps2_clk(ps2_clk),          // 10kHz
        .rst(rst_sync) ,      // 复位信号，低电平有效
        .ps2_mode(ps2_mode), // 模式
        .btn_grp1(btn_grp1), // 按键组1
        .btn_grp2(btn_grp2), // 按键组2
        .rhandle_X(rhandle_X), // 右手柄 X 轴
        .rhandle_Y(rhandle_Y), // 右手柄 Y 轴
        .lhandle_X(lhandle_X), // 左手柄 X 轴
        .lhandle_Y(lhandle_Y), // 左手柄 Y 轴
        .ready(ready), // 是否准备好，1表示准备好，0表示正在读取数据
        .pmod_io1(pmod1_io1), // MOSI
        .pmod_io2(pmod1_io2), // MISO
        .pmod_io3(pmod1_io3), // SCLK
        .pmod_io4(pmod1_io4)  // CS
    );
    // !!!!!!!!!!语法上，即使最后多加了一个逗号也会报错！
    always @(posedge ps2_clk) begin
        if(rst_sync) begin
            number <= 32'd0;
            //因为ready是在内部输出的，所以这里不应该再进行初始化
        end else if(ready)begin
            //测试：ready=1代表这一个周期的手柄信号可以读取，
            number[7:0] <= btn_grp1;
            number[15:8] <= btn_grp2;
            number[23:16] <= rhandle_X;
            number[31:24] <= rhandle_Y;
        end else begin
            number <= number;
        end
    end
    
    assign video_clk = clk_hdmi;
    video #(12, 800, 856, 976, 1040, 600, 637, 643, 666, 1, 1) u_video800x600at72 ( //对模块进行实例化（可以实例化为多个）
        .clk(video_clk), 
        .hdata(hdata), //横坐标
        .vdata(vdata), //纵坐标
        .hsync(video_hsync),
        .vsync(video_vsync),
        .data_enable(video_de),
        .red(video_red),
        .green(video_green),
        .blue(video_blue),
        .btn_grp1(btn_grp1),
        .btn_grp2(btn_grp2),
        .rhandle_X(rhandle_X),
        .rhandle_Y(rhandle_Y),
        .lhandle_X(lhandle_X),
        .lhandle_Y(lhandle_Y)
    );

    // 把 RGB 转化为 HDMI TMDS 信号并输出
    ip_rgb2dvi u_ip_rgb2dvi (
        .PixelClk   (video_clk),
        .vid_pVDE   (video_de),
        .vid_pHSync (video_hsync),
        .vid_pVSync (video_vsync),
        .vid_pData  ({video_red, video_blue, video_green}),
        .aRst       (~clk_locked),

        .TMDS_Clk_p  (hdmi_tmds_c_p),
        .TMDS_Clk_n  (hdmi_tmds_c_n),
        .TMDS_Data_p (hdmi_tmds_p),
        .TMDS_Data_n (hdmi_tmds_n)
    );

endmodule
