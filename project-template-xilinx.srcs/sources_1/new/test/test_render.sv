`timescale 1ns / 1ps
module test_render(
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
    // 自己控制
    reg asram_io_req;
    reg [19:0] atimes;
    reg awr;
    reg [19:0] aaddr;
    reg [31:0] adin;
    wire [31:0] adout;


    /////////////////////////// SRAM /////////////////
    wire sram_io_req;
    wire [19:0] times;
    wire wr;
    wire [19:0] addr;
    wire [31:0] din;
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

    /////////////////// RENDER /////////////////
    wire lsram_io_req;
    wire [19:0] ltimes;
    wire lwr;
    wire [19:0] laddr;
    wire [31:0] ldin;
    wire [31:0] ldout;

    reg vm_flag;
    reg [11:0] hpos;
    reg [11:0] vpos;
    reg [15:0] line_buffer[31:0];
    reg render_begin;
    wire render_end;
    reg last_render_end;
    initial begin
        for(integer i=0; i< 32; i = i+1)begin
            line_buffer[i][15:8] = 2*i;
            line_buffer[i][7:0] = 2*i+1;
        end
    end
    line_render u_line_render(
        .line_render_ui_clk(clk_100m),
        .ui_rst(btn_rst),
        .hpos(hpos),
        .vpos(vpos),
        .vm_flag(vm_flag),
        .render_begin(render_begin),
        .render_end(render_end),
        .line_buffer(line_buffer),
        .sram_io_req(lsram_io_req),
        .times(ltimes),
        .wr(lwr),
        .addr(laddr),
        .din(ldin),
        .dout(ldout)
    );
    ///////////////////////
    reg [3:0] stat;
    reg [31:0] show_data [15:0];
    localparam [3:0] IDLE=0, RENDER=1,PRE_READ=2, READ1=3, READ2=4 ,SHOW=5;

    assign sram_io_req = (stat == RENDER) ? lsram_io_req : asram_io_req;
    assign times = (stat == RENDER) ? ltimes : atimes;
    assign wr = (stat == RENDER) ? lwr : awr;
    assign addr = (stat == RENDER) ? laddr : aaddr;
    assign din = (stat == RENDER) ? ldin : adin;
    assign adout = dout;
    assign ldout = dout;

    reg [31:0] render_counter;
    reg [5:0] show_counter;
    always@(posedge clk_100m)begin
        if(btn_rst)begin
            stat <=IDLE;
            show_counter <= 0;
        end else begin
            if(stat == IDLE)begin
                stat <= RENDER;
                hpos <= 0;
                vpos <= 0;
                vm_flag <= 0;
            end else if(stat == RENDER)begin
                render_begin <= 1;
                if(~last_render_end & render_end)begin
                    render_begin <= 0;
                    stat <= PRE_READ;
                    awr <= 0;
                    asram_io_req <= 1;
                end
            end else if(stat == PRE_READ)begin
                atimes <= 16;
                aaddr <= 0;
                stat <= READ1;
                // 展示状态，读取 SRAM前16个地址的值
            end else if(stat == READ1)begin
                asram_io_req <= 0;
                stat <= READ2;
            end else if(stat == READ2)begin
                show_data[show_counter] <= adout;
                if(show_counter == 15)begin
                    show_counter <= 0;
                    stat <= SHOW;
                end else begin
                    show_counter <= show_counter + 1;
                    aaddr <= aaddr + 1;     // 读取下一个位置
                    stat <= READ1;
                end
            end else begin      // SHOW
                if(render_counter >= 100000000)begin
                    render_counter <= 0;
                    number[31:24] <= show_counter;
                    number[23:0] <= show_data[show_counter][31:8];      // 显示前3个字节
                    if(show_counter == 15)begin
                        show_counter <= 0;
                    end else begin
                        show_counter <= show_counter + 1;
                    end
                end else begin
                    render_counter <= render_counter + 1;
                end
            end
            last_render_end <= render_end;
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
