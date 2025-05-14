/*********   资源管理器   *********/
// 将SDRAM和SD卡统一管理
// 在INIT阶段，将SD卡中的数据读取到
module sources_namager(
    input clk_100m,
    input rst,
    /****** 对外硬件接口 *****/
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
    // SD 卡（SPI 模式）
    output wire        sd_sclk,     // SPI 时钟
    output wire        sd_mosi,     // 数据输出
    input  wire        sd_miso,     // 数据输入
    output wire        sd_cs,       // SPI 片选，低有效
    input  wire        sd_cd,       // 卡插入检测，0 表示有卡插入
    input  wire        sd_wp,       // 写保护检测，0 表示写保护状态

);

    //产生 SD卡 5MHz时钟
    reg clk_sd_spi;
    reg [3:0] sd_spi_clk_counter;
    always@(posedge clk_100m)begin
        if(rst)begin
            sd_spi_clk_counter <= 4'd0;
            clk_sd_spi <= 1'b0;
        end else begin
            if(sd_spi_clk_counter == 4'd9)begin
                clk_sd_spi <= ~clk_sd_spi;
                sd_spi_clk_counter <= 4'd0;
            end else begin
                sd_spi_clk_counter <= sd_spi_clk_counter + 4'd1;
            end
        end 
    end
    // SD 卡读取演示
    reg [31:0] sdc_address;
    wire sdc_ready;

    reg sdc_read;
    wire [7:0] sdc_read_data;
    wire sdc_read_valid;

    sd_controller u_sd_controller (
        .clk                (clk_sd_spi),      // 5MHz
        .reset              (~clk_locked),

        .cs                 (sd_cs),
        .mosi               (sd_mosi),
        .miso               (sd_miso),
        .sclk               (sd_sclk),

        .address            (sdc_address),
        .ready              (sdc_ready),

        .rd                 (sdc_read),
        .dout               (sdc_read_data),
        .byte_available     (sdc_read_valid)
    );

    reg [1:0] state_reg;
    localparam STATE_INIT = 2'd0;
    localparam STATE_READ = 2'd1;
    localparam STATE_FINISH = 2'd2;

    reg [7:0] mem [511:0];
    reg [8:0] write_byte;
    reg [8:0] read_byte;

    reg [31: 0] counter;
    always @(posedge clk_spi) begin
        if (~clk_locked) begin
            counter <= 32'b0;
            number <= 32'b0;

            sdc_address <= 32'b0;
            sdc_read <= 1'b0;

            state_reg <= STATE_INIT;
            write_byte <= 9'b0;
            read_byte <= 9'b0;
        end else begin
            counter <= counter + 32'b1;
            if (counter == 32'd5_000_000) begin
                counter <= 32'b0;
                read_byte <= read_byte + 9'b1;
            end

            casez(state_reg)
                STATE_INIT: begin
                    if (sdc_ready) begin
                        sdc_read <= 1'b1;
                        state_reg <= STATE_READ;
                    end
                end
                STATE_READ: begin
                    sdc_read <= 1'b0;

                    if (sdc_read_valid) begin
                        mem[write_byte] <= sdc_read_data;
                        write_byte <= write_byte + 9'b1;
                    end
                    if (write_byte == 9'd511) begin
                        state_reg <= STATE_FINISH;
                    end
                end
                default: begin
                end
            endcase
        end
    end



endmodule