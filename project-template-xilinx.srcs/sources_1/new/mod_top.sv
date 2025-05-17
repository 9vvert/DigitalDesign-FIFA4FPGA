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

    /*************   SD卡    *************/
    reg sd_read_start;
    reg sd_read_end;
    reg [31:0] sd_addr;
    reg [7:0] sd_buffer[511:0];
    sd_IO u_sd_IO(
        .clk_100m(clk_100m),
        .rst(~clk_locked),
        // SD 卡（SPI 模式）
        .sd_sclk(sd_sclk),     // SPI 时钟
        .sd_mosi(sd_mosi),     // 数据输出
        .sd_miso(sd_miso),     // 数据输入
        .sd_cs(sd_cs),       // SPI 片选，低有效
        .sd_cd(sd_cd),       // 卡插入检测，0 表示有卡插入
        .sd_wp(sd_wp),       // 写保护检测，0 表示写保护状态
        //对外接口
        .read_start(sd_read_start),               // 因为SD卡频率较慢，外界必须等待一段时间才能将raed_start降低
        .read_end(sd_read_end),                // 加载完成
        .sd_src_addr(sd_addr),       // SD卡
        .mem(sd_buffer)
    );

    /***********  SDRAM  ************/
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

        // .sdram_info(number[7:0]),
        //对外接口
        .sdram_cmd(sdram_cmd),          //命令，  0无效，1读取，2写入
        .operate_addr(sdram_addr),      //地址
        .write_data(sdram_write_data),
        .read_data(sdram_read_data),
        .cmd_done(cmd_done)             //这一轮命令结束
    );
    
    /******************  ImgLoader  ****************/
    reg load_start;
    reg load_end;
    reg last_load_end;
    reg [11:0] img_width;
    reg [11:0] img_height;
    reg [31:0] sd_start_addr;
    reg [29:0] sdram_start_addr;
    //控制信息
    wire loader_sd_read_start;
    wire [31:0] loader_curr_sd_addr;
    ///////////// 一定一定要检查信号宽度，2025.5.15日我因为loader_sdram_cmd误写成一位而被折磨了2个小时
    wire [1:0] loader_sdram_cmd;
    wire [29:0] loader_curr_sdram_addr;
    wire [63:0] loader_sdram_buffer;
    async_ImgLoader u_async_ImgLoader(
        //数据总信息
        // .debug_number(number),
        .ui_clk(ui_clk),       // 仍旧使用显存的时钟频率
        .ui_rst(ui_clk_sync_rst),
        .load_start(load_start),           //开始加载一个命令
        .load_end(load_end),        //图片加载结束，可以开始下一次加载
        .in_width(img_width),         
        .in_height(img_height),        // 最终读取的数据量为：img_width*img_height*3 bytes
        .sd_start_addr(sd_start_addr),    // SD卡图片的起始地址
        .sdram_start_addr(sdram_start_addr),  // SDRAM待写入的起始地址
        // .loader_info(number[31:8]),
        //SD
        .loader_sd_read_end(sd_read_end),
        .loader_sd_read_start(loader_sd_read_start),
        .loader_curr_sd_addr(loader_curr_sd_addr),
        .loader_sd_buffer(sd_buffer),      // 从sd卡读取的数据
        //SDRAM
        .loader_sdram_write_end(cmd_done),
        .loader_sdram_cmd(loader_sdram_cmd),           // SDRAM输出命令，这里仅仅使用2来写入
        .loader_curr_sdram_addr(loader_curr_sdram_addr),      // SDRAM输出的地址
        .loader_sdram_buffer(loader_sdram_buffer)          // 向SDRAM输出的数据
    );
    /*************   显存仲裁器   ************/
    localparam [3:0] UNINIT=0 ,IDLE=1, LOAD=2, RENDER=3, SHOW1=4,SHOW2=5,SHOW3=6,SHOW4=7;
    reg [3:0]vm_stat;       //显存状态
    reg last_sdram_read_end;
    reg [15:0] a1;
    reg [15:0] a2;
    reg [15:0] a3;
    reg [15:0] a4;
    reg [63:0] delay_show_counter;  //用于交替显示数字
    always @(posedge ui_clk)begin       //显存逻辑：使用sdram输出的时钟
        if(ui_clk_sync_rst)begin
            vm_stat <= UNINIT;
            a1<=0;
            a2<=0;
            a3<=0;
            a4<=0;
            load_start <= 1'b0;
            last_load_end <= 1'b0;
            last_sdram_read_end <= 0;
            delay_show_counter <= 0;
        end else begin
            if(vm_stat == UNINIT)begin
                if(sdram_init_calib_complete)begin
                    vm_stat <= LOAD;        // SDRAM初始化完成，进入Load Sources状态
                end
            end else if(vm_stat == LOAD)begin
                //仲裁器，将SDRAM的接口与ImgLoader对接
                sd_read_start <= loader_sd_read_start;
                sd_addr <= loader_curr_sd_addr;
                sdram_cmd <= loader_sdram_cmd;
                sdram_addr <= loader_curr_sdram_addr;
                sdram_write_data <= loader_sdram_buffer;
                //
                img_width <= 32;
                img_height <= 32;
                sd_start_addr <= 5120 ;         //SD卡的第十个扇区
                sdram_start_addr <= 512;        //从SDRAM的512号地址开始
                load_start <= 1'b1;     //开始加载数据
                if( (~last_load_end) & load_end )begin
                    load_start <= 1'b0;
                    vm_stat <= SHOW1;
                end
            end else if(vm_stat == SHOW1)begin
                // 从SDRAM中取样
                sdram_cmd <= 2'd1;
                sdram_addr <= 792;
                if( (~last_sdram_read_end) & cmd_done)begin
                    sdram_cmd <= 2'd0;
                    a1 <= sdram_read_data [63:48];
                    vm_stat <= SHOW2;
                end
            end else if(vm_stat == SHOW2)begin
                // 从SDRAM中取样
                sdram_cmd <= 2'd1;
                sdram_addr <= 1246;
                if( (~last_sdram_read_end) & cmd_done)begin
                    sdram_cmd <= 2'd0;
                    a2 <= sdram_read_data [63:48];
                    vm_stat <= SHOW3;
                end
            end else if(vm_stat == SHOW3)begin
                // 从SDRAM中取样
                sdram_cmd <= 1;
                sdram_addr <= 1696;
                if( (~last_sdram_read_end) & cmd_done)begin
                    sdram_cmd <= 0;
                    a3 <= sdram_read_data [63:48];
                    vm_stat <= SHOW4;
                end
            end else if(vm_stat == SHOW4)begin
                // 从SDRAM中取样
                sdram_cmd <= 1;
                sdram_addr <= 2532;
                if( (~last_sdram_read_end) & cmd_done)begin
                    sdram_cmd <= 0;
                    a4 <= sdram_read_data [63:48];
                    vm_stat <= RENDER;
                end
            end else begin
                if(delay_show_counter < 64'd100000000)begin
                    number [31:16] <= a1;
                    number [15:0] <= a2;
                    delay_show_counter <= delay_show_counter + 1;
                end else if(delay_show_counter < 64'd200000000)begin
                    number [31:16] <= a3;
                    number [15:0] <= a4;
                    delay_show_counter <= delay_show_counter + 1;
                end else begin
                    delay_show_counter <= 0;
                end
            end
            last_sdram_read_end <= cmd_done;     //
            last_load_end <= load_end;
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
        .a1(a1),
        .a2(a2),
        .a3(a3),
        .a4(a4),
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
        .vid_pData  ({video_red, video_blue, video_green}),
        // .vid_pData  ({read_R, read_B, read_G}),
        .aRst       (~clk_locked),

        .TMDS_Clk_p  (hdmi_tmds_c_p),
        .TMDS_Clk_n  (hdmi_tmds_c_n),
        .TMDS_Data_p (hdmi_tmds_p),
        .TMDS_Data_n (hdmi_tmds_n)
    );

endmodule
