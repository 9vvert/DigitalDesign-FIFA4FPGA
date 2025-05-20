`timescale 1ns / 1ps
module test_sram(
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
    inout  wire [31:0] base_ram_data,   // SRAM 数据
    output wire [19:0] base_ram_addr,   // SRAM 地址
    output wire [3: 0] base_ram_be_n,   // SRAM 字节使能，低有效。如果不使用字节使能，请保持为0
    output wire        base_ram_ce_n,   // SRAM 片选，低有效
    output wire        base_ram_oe_n,   // SRAM 读使能，低有效
    output wire        base_ram_we_n   // SRAM 写使能，低有效


    );
    assign base_ram_be_n = 0;
    // 使用 100MHz 时钟作为后续逻辑的时钟
    wire clk_in = clk_100m;

    // 七段数码管扫描演示
    reg [31:0] number;
    dpy_scan u_dpy_scan (
        .clk     (clk_in      ),
        .number  (number      ),
        .dp      (8'b0        ),

        .digit   (dpy_digit   ),
        .segment (dpy_segment )
    );

    reg [31:0] buffer[11:0];        //读取12个数据
    reg sram_io_req;
    reg [19:0] times;
    reg wr;
    reg [19:0] addr;
    reg [31:0] din;
    wire [31:0] dout;

    sram_IO u_sram_IO(
        .clk(clk_100m),
        .rst(btn_rst),
        .req(sram_io_req),
        .times(times),
        .addr(addr),
        .wr(wr),
        .din(din),
        .dout(dout),
        .base_ram_data(base_ram_data),
        .base_ram_addr(base_ram_addr),
        .base_ram_be_n(base_ram_be_n),
        .base_ram_ce_n(base_ram_ce_n),
        .base_ram_oe_n(base_ram_oe_n),
        .base_ram_we_n(base_ram_we_n)
    );
    reg [3:0] stat;
    reg [7:0] sram_cnt;
    reg [31:0] show_counter;
    localparam [3:0] IDLE=0, READ1=1, READ2=2, WRITE1=3, WRITE2=4, WRITE3=5, PRE_READ=6, PRE_WRITE=7,DONE=8;
    always@(posedge clk_100m)begin
        if(btn_rst)begin
            sram_cnt <= 0;
            stat <= IDLE;
            wr <= 0;
            addr <= 0;
            show_counter <= 0;
        end else begin
            case(stat)
                IDLE: begin
                    wr <= 1;
                    // 必须在拉高wr的同时输入din
                    addr <= sram_cnt;   //使用计数器作为地址
                    din <= {sram_cnt, sram_cnt+8'd1, sram_cnt+8'd2,sram_cnt +8'd3};
                    stat <= PRE_WRITE;
                    sram_io_req <= 1;       //拉高请求
                end 
                PRE_READ:begin
                    addr <= sram_cnt;
                    times <= 'd12;
                    stat <= READ1;
                end
                PRE_WRITE:begin
                    wr <= 1;
                    times <= 'd12;
                    
                    stat <= WRITE1;
                end
                READ1: begin
                    stat <= READ2;
                end
                READ2: begin
                    //安全拉低req
                    buffer[sram_cnt] <= dout; 
                    sram_io_req <= 0;
                    if(sram_cnt == times)begin
                        stat <= DONE;
                    end else begin
                        wr <= 0;
                        addr <= sram_cnt;
                        sram_cnt <= sram_cnt + 1;
                        stat <= READ1;
                    end
                end
                WRITE1: begin
                    stat <= WRITE2;
                end
                WRITE2: begin
                    sram_io_req <= 0;
                    stat <= WRITE3;
                end
                WRITE3: begin
                    if(sram_cnt == times)begin
                        sram_cnt <= 0;
                        sram_io_req <= 1;
                        wr <= 0;
                        stat <= PRE_READ;
                    end else begin
                        addr <= sram_cnt;
                        din <= {sram_cnt+1, sram_cnt+8'd2, sram_cnt+8'd3,sram_cnt +8'd4};
                        sram_cnt <= sram_cnt + 1;
                        stat <= WRITE1;
                    end
                end
                DONE:begin
                    if(show_counter == 32'd100000000)begin
                        show_counter <= 0;
                        number[15:0] <= sram_cnt;
                        number[31:16] <= buffer[sram_cnt];
                        if(sram_cnt >= 11)begin
                            sram_cnt <= 0;
                        end else begin
                            sram_cnt <= sram_cnt + 1;
                        end
                    end else begin
                        show_counter <= show_counter +  1;
                    end
                end
            endcase
        end
    end

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

endmodule
