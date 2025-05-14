/*******  img_reader ********/
// 读取SD卡指定位置，特定大小的文件
module img_reader(
    input clk_100m,
    input rst,
    // SD 卡（SPI 模式）
    output wire        sd_sclk,     // SPI 时钟
    output wire        sd_mosi,     // 数据输出
    input  wire        sd_miso,     // 数据输入
    output wire        sd_cs,       // SPI 片选，低有效
    input  wire        sd_cd,       // 卡插入检测，0 表示有卡插入
    input  wire        sd_wp,       // 写保护检测，0 表示写保护状态
    //对外接口
    input load_start,  
    output load_end,                // 加载完成
    input [31:0] sd_src_addr,       // SD卡
    input [15:0] in_width,         
    input [15:0] in_height,        // 最终读取的数据量为：img_width*img_height*3 bytes
    output reg [7:0] mem [511:0],
    output reg batch_valid,         // 有<=512字节可以读取
    output reg [9:0] valid_count,   // 因为每次是按照扇区来读取，所以有些数值可能是无效的
);
    reg [15:0] img_width;
    reg [15:0] img_height;
    reg [31:0] totalBytes;
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
    localparam STATE_FINISH = 3'd2;
    localparam IDLE = 3'd3;         //闲置状态
    localparam DONE = 3'd4;

    reg [8:0] read_byte;
    reg [1:0] delay_counter;    //用于finish阶段
    always @(posedge clk_sd_spi) begin
        if (rst) begin
            batch_valid <= 1'b0;
            sdc_address <= 32'b0;
            sdc_read <= 1'b0;
            img_height <= 16'd0;
            img_width <= 16'd0;
            totalBytes <= 32'd0;
            state_reg <= IDLE;
            read_byte <= 9'b0;
            delay_counter <= 2'd0;
        end else begin
            casez(state_reg)
                IDLE:begin
                    if(load_start)begin //捕捉上升沿
                        state_reg <= STATE_INIT;
                        img_height = in_height;
                        img_width = in_width;
                        totalBytes = img_height * img_width * 3;
                        sdc_address <= sd_src_addr;
                    end
                end
                STATE_INIT: begin       //等待sdc_ready信号
                    if (sdc_ready) begin
                        if(totalBytes >= 32'd512)begin
                            valid_count <= 10'd512;
                            totalBytes <= totalBytes - 32'd512;
                        end else begin
                            valid_count <= totalBytes;  //这里必须用非阻塞赋值
                            totalBytes <= 32'd0;
                        end
                        sdc_read <= 1'b1;   //将sdc_read信号拉高一个周期
                        state_reg <= STATE_READ;
                        batch_valid <= 1'b0;
                        read_byte <= 9'd0;      //计数器清零
                        delay_counter <= 2'd0;
                    end
                end
                STATE_READ: begin
                    sdc_read <= 1'b0;

                    if (sdc_read_valid) begin
                        mem[read_byte] <= sdc_read_data;
                        read_byte <= read_byte + 9'b1;
                    end
                    if (read_byte == 9'd511) begin      //读取完一整个扇区
                        state_reg <= STATE_FINISH;
                    end
                end
                STATE_FINISH: begin
                    if(delay_counter == 2'd0)begin
                        batch_valid <= 1'b1;    //拉高一个周期
                        delay_counter <= delay_counter + 2'd1;
                    end if(delay_counter < 2'd3)begin
                        delay_counter <= delay_counter + 2'd1; 
                    end else begin
                        delay_counter <= 2'd0;
                        if(totalBytes > 0)begin
                            sdc_address <= sdc_address + 512;   //下一个扇区的地址
                            state_reg <= STATE_INIT;    // 开启下一个扇区
                        end else begin
                            state_reg <= DONE;          // 结束
                            load_end <= 1'b1;           // 拉高一个周期
                        end 
                    end
                end
                default: begin
                    load_end <= 1'b0;
                    state_reg <= IDLE;
                end
            endcase
        end
    end

endmodule