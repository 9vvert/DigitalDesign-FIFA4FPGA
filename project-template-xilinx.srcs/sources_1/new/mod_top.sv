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
    wire clk_hdmi;
    wire clk_ddr;
    wire clk_ref;
    wire clk_locked;
    ip_pll u_ip_pll(
        .clk_in1  (clk_in    ),  // 输入 100MHz 时钟
        .reset    (btn_rst   ),  // 复位信号，高有效
        .clk_out1 (clk_hdmi  ),  // 50MHz 像素时钟
        .clk_out2 (clk_ref   ),  // 200MHz DDR 参考时钟
        .clk_out3 (clk_ddr   ),  // 400MHz DDR 控制器时钟
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

    // img_reader u_reader(
    // input clk_100m,
    // input rst,
    // // SD 卡（SPI 模式）
    // output wire        sd_sclk,     // SPI 时钟
    // output wire        sd_mosi,     // 数据输出
    // input  wire        sd_miso,     // 数据输入
    // output wire        sd_cs,       // SPI 片选，低有效
    // input  wire        sd_cd,       // 卡插入检测，0 表示有卡插入
    // input  wire        sd_wp,       // 写保护检测，0 表示写保护状态
    // //对外接口
    // input load_start,  
    // output load_end,                // 加载完成
    // input [31:0] sd_src_addr,       // SD卡
    // input [15:0] in_width,         
    // input [15:0] in_height,        // 最终读取的数据量为：img_width*img_height*3 bytes
    // output reg [7:0] mem [511:0],
    // output reg batch_valid,         // 有<=512字节可以读取
    // output reg [9:0] valid_count,   // 因为每次是按照扇区来读取，所以有些数值可能是无效的
    // );

    reg [7:0] read_R;
    reg [7:0] read_G;
    reg [7:0] read_B;
    reg [2:0] sdram_controller_stat;    //
    wire ui_clk;                    // SDRAM时钟，用于和显存相关的所有时序逻辑
    wire ui_clk_sync_rst;
    reg [1:0]sdram_cmd;
    reg [29:0]sdram_addr;
    reg [63:0]sdram_write_data;
    reg [63:0]sdram_read_data;
    reg sdram_init_done;
    reg cmd_done;
    reg last_cmd_done;
    wire sdram_init_calib_complete; //检测到为高的时候，SDRAM正式进入可用状态
    /***********  SDRAM  ************/
    sdram_IO u_sdram_IO(
        .ui_clk(ui_clk),
        .ui_clk_sync_rst(ui_clk_sync_rst),
        .init_calib_complete(sdram_init_calib_complete),
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

        .sys_clk_i(clk_ddr),  // 400MHz
        .clk_ref_i(clk_ref),  // 200MHz
        .sys_rst(!clk_locked),

        //对外接口
        .sdram_cmd(sdram_cmd),          //命令，  0无效，1读取，2写入
        .operate_addr(sdram_addr),      //地址
        .write_data(sdram_write_data),
        .read_data(sdram_read_data),
        .cmd_done(cmd_done)             //这一轮命令结束
    );
    always @(posedge ui_clk)begin       //显存逻辑：使用sdram输出的时钟
        if(ui_clk_sync_rst)begin
            sdram_init_done <= 1'b0;
            sdram_controller_stat <= 3'd0;
            last_cmd_done<= 1'b0;
        end else begin
            if(sdram_init_calib_complete)begin
                sdram_init_done <= 1'b1;
            end
            if(sdram_init_done)begin
                if(sdram_controller_stat == 3'd0)begin
                    number[8:8] = 1;
                    // 尝试写入8个字节
                    sdram_write_data <= {8'h0a,8'h2a,8'h4a,8'h6a,8'h8a,8'haa,8'hca,8'hea};
                    sdram_addr <= 'd16;
                    sdram_cmd = 2;
                    if( (~last_cmd_done) & cmd_done)begin   //捕捉上升时刻
                        number[9:9] = 1;
                        sdram_cmd = 0;      // 及时撤销命令 
                        sdram_controller_stat <= 3'd1;
                    end
                end else if(sdram_controller_stat == 3'd1)begin
                    number[10:10] = 1;
                    sdram_addr <= 'd16;
                    sdram_cmd = 1;
                    if( (~last_cmd_done) & cmd_done)begin
                        number[11:11] = 1;
                        sdram_cmd = 0;
                        sdram_controller_stat <= 3'd2;
                    end
                end else begin
                    read_R <= sdram_read_data[7:0];
                    read_G <= sdram_read_data[15:8];
                    read_B <= sdram_read_data[23:16];
                    number[7:0] <= sdram_read_data[7:0];
                    number[31:24] <= sdram_read_data[63:56];
                end
            end

            last_cmd_done = cmd_done;
        end
    end


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

    assign video_clk = clk_hdmi;
    video #(12, 800, 856, 976, 1040, 600, 637, 643, 666, 1, 1) u_video800x600at72 (
        .clk(video_clk), 
        .hdata(hdata), //横坐标
        .vdata(vdata), //纵坐标
        .hsync(video_hsync),
        .vsync(video_vsync),
        .data_enable(video_de),
        .red(video_red),
        .green(video_green),
        .blue(video_blue)
    );

    // 把 RGB 转化为 HDMI TMDS 信号并输出
    ip_rgb2dvi u_ip_rgb2dvi (
        .PixelClk   (video_clk),
        .vid_pVDE   (video_de),
        .vid_pHSync (video_hsync),
        .vid_pVSync (video_vsync),
        // .vid_pData  ({video_red, video_blue, video_green}),
        .vid_pData  ({read_R, read_B, read_G}),
        .aRst       (~clk_locked),

        .TMDS_Clk_p  (hdmi_tmds_c_p),
        .TMDS_Clk_n  (hdmi_tmds_c_n),
        .TMDS_Data_p (hdmi_tmds_p),
        .TMDS_Data_n (hdmi_tmds_n)
    );

endmodule
