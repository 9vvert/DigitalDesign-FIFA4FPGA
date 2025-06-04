/*******  img_reader ********/
// 读取SD卡指定位置，特定大小的文件
// 该时钟为5MHz，较慢，外部可以使用高频时钟，捕捉其上升沿
// 和SDRAM不同，SD卡不需要外界等待初始化
module sd_IO(
    input ui_clk,
    input rst,
    // SD 卡（SPI 模式）
    output wire        sd_sclk,     // SPI 时钟
    output wire        sd_mosi,     // 数据输出
    input  wire        sd_miso,     // 数据输入
    output wire        sd_cs,       // SPI 片选，低有效
    input  wire        sd_cd,       // 卡插入检测，0 表示有卡插入
    input  wire        sd_wp,       // 写保护检测，0 表示写保护状态
    //对外接口
    input read_start,               // 因为SD卡频率较慢，外界必须等待一段时间才能将raed_start降低
    output reg read_end,                // 加载完成
    input [31:0] sd_src_addr,       // SD卡
    output reg [7:0] mem [511:0]
);
    //产生 SD卡 5MHz时钟
    reg clk_sd_spi;
    reg [3:0] sd_spi_clk_counter;
    always@(posedge ui_clk)begin
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
        .reset              (rst),

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

    reg [2:0] state_reg;
    localparam STATE_INIT = 3'd0;
    localparam STATE_READ = 3'd1;
    localparam STATE_FINISH = 3'd2; //[TODO]删去冗余状态
    localparam IDLE = 3'd3;         //闲置状态
    localparam DONE = 3'd4;
    reg done_delay_counter;
    reg [8:0] read_byte;            // 每次读取一个字节
    always @(posedge clk_sd_spi) begin
        if (rst) begin
            sdc_address <= 32'b0;
            sdc_read <= 1'b0;
            state_reg <= IDLE;
            read_byte <= 9'b0;
            done_delay_counter <= 0;
        end else begin
            casez(state_reg)
                IDLE:begin
                    read_end <= 0;
                    if(read_start)begin //捕捉上升沿
                        state_reg <= STATE_INIT;
                        sdc_address <= sd_src_addr;
                    end
                end
                STATE_INIT: begin       //等待sdc_ready信号
                    if (sdc_ready) begin
                        sdc_read <= 1'b1;   //将sdc_read信号拉高一个周期
                        state_reg <= STATE_READ;
                        read_byte <= 9'd0;      //计数器清零
                    end
                end
                STATE_READ: begin
                    sdc_read <= 1'b0;
                    if (sdc_read_valid) begin
                        mem[read_byte] <= sdc_read_data;
                        read_byte <= read_byte + 9'b1;
                    end
                    if (read_byte == 9'd511) begin      //读取完一整个扇区
                        read_end <= 1'b1;       //结束标志，拉高
                        done_delay_counter <= 0;
                        state_reg <= DONE;
                    end
                end
                default: begin
                    read_end <= 1;
                    if(done_delay_counter == 0)begin
                        done_delay_counter <= 1;
                    end else begin
                        done_delay_counter <= 0;
                        state_reg <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule