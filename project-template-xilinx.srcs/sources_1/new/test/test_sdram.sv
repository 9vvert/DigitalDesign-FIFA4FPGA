`timescale 1ns / 1ps
module test_sdram(
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
    output wire [0 :0] ddr3_odt

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

        reg [2:0] sdram_controller_stat;    //
    wire ui_clk;                 // 由SDRAM输出
    wire ui_rst;
    reg [1:0]sdram_cmd;
    reg [29:0]sdram_addr;
    reg [63:0]sdram_write_data;
    reg [63:0]sdram_read_data;
    reg cmd_done;
    wire sdram_init_calib_complete; //检测到为高的时候，SDRAM正式进入可用状态
    sdram_IO u_sdram_IO(
        .ui_clk(ui_clk),
        .ui_clk_sync_rst(ui_rst),
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

    // 状态机定义
    typedef enum logic [2:0] {
        IDLE,
        WRITE,
        WRITE_WAIT,
        READ,
        READ_WAIT,
        DELAY
    } sdram_state_t;

    sdram_state_t state;
    reg [5:0] write_cnt;
    reg [5:0] read_cnt;
    reg [29:0] addr;
    reg [31:0] debug_number;
    reg [31:0] delay_cnt;

    assign number = debug_number; // 将调试数字输出到数码管
    // 写入数据固定模式
    localparam [63:0] WRITE_PATTERN = {8'd7,8'd8,8'd5,8'd6,8'd3,8'd4,8'd1,8'd2};
    localparam [29:0] START_ADDR = 30'd0;
    localparam [29:0] ADDR_STEP = 30'd8;
    localparam [31:0] DELAY_1S = 32'd100_000_000; // 1s @ 100MHz

    always @(posedge ui_clk) begin
        if (ui_rst) begin
            state <= IDLE;
            write_cnt <= 0;
            read_cnt <= 0;
            addr <= START_ADDR;
            sdram_cmd <= 0;
            sdram_write_data <= 0;
            debug_number <= 0;
            delay_cnt <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (sdram_init_calib_complete) begin
                        // 开始写入
                        state <= WRITE;
                        write_cnt <= 0;
                        addr <= START_ADDR;
                    end
                end
                WRITE: begin
                    sdram_cmd <= 2; // 写命令
                    sdram_write_data <= WRITE_PATTERN;
                    sdram_addr <= addr;
                    state <= WRITE_WAIT;
                end
                WRITE_WAIT: begin
                    if (cmd_done) begin
                        sdram_cmd <= 0;
                        if (write_cnt == 6'd63) begin
                            // 写完64次，准备读
                            state <= READ;
                            read_cnt <= 0;
                            addr <= START_ADDR;
                        end else begin
                            // 继续写
                            write_cnt <= write_cnt + 1;
                            addr <= addr + ADDR_STEP;
                            state <= WRITE;
                        end
                    end
                end
                READ: begin
                    sdram_cmd <= 1; // 读命令
                    sdram_addr <= addr;
                    state <= READ_WAIT;
                end
                READ_WAIT: begin
                    if (cmd_done) begin
                        sdram_cmd <= 0;
                        debug_number <= sdram_read_data[31:0];
                        delay_cnt <= 0;
                        state <= DELAY;
                    end
                end
                DELAY: begin
                    if (delay_cnt < DELAY_1S) begin
                        delay_cnt <= delay_cnt + 1;
                    end else begin
                        if (read_cnt == 6'd63) begin
                            state <= IDLE; // 读完64次，回到IDLE
                        end else begin
                            read_cnt <= read_cnt + 1;
                            addr <= addr + 1;
                            state <= READ;
                        end
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end


endmodule
