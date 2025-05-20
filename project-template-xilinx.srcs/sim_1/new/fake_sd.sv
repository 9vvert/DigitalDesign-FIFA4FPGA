// fake_sd.sv
// 模拟 SD 卡接口，仅保留 4 个接口：read_start, read_end, sd_src_addr, mem
// 接收 clk_100m 和 rst，内部产生 5MHz 的 SD 时钟
// 读请求时等待 10 个 5MHz 周期后输出 read_end 信号
// 每个mem[i]的内容为 (addr[15:8] + addr[7:0])，addr = sd_src_addr + i，结果自然溢出

module fake_sd (
    input  wire        clk_100m,
    input  wire        rst,
    input  wire        read_start,          // 读请求开始
    output reg         read_end,            // 读完成
    input  wire [31:0] sd_src_addr,         // SD卡地址（可选模拟用）
    output reg  [7:0]  mem [511:0]          // 模拟存储区
);

    // 产生 5MHz SD 时钟 (clk_sd)
    reg clk_sd;
    reg [3:0] clk_sd_cnt;
    always @(posedge clk_100m or posedge rst) begin
        if (rst) begin
            clk_sd_cnt <= 4'd0;
            clk_sd <= 1'b0;
        end else begin
            if (clk_sd_cnt == 4'd9) begin // 分频, 100MHz/10/2 = 5MHz
                clk_sd <= ~clk_sd;
                clk_sd_cnt <= 4'd0;
            end else begin
                clk_sd_cnt <= clk_sd_cnt + 4'd1;
            end
        end
    end

    // 状态机定义
    typedef enum logic [1:0] {
        S_IDLE   = 2'd0,
        S_WAIT   = 2'd1,
        S_WRITE  = 2'd2,
        S_DONE   = 2'd3
    } state_t;

    state_t state, next_state;
    reg [3:0] wait_cnt;

    // 读请求沿捕获
    reg read_start_d;
    always @(posedge clk_sd or posedge rst) begin
        if (rst)
            read_start_d <= 1'b0;
        else
            read_start_d <= read_start;
    end
    wire read_start_posedge = read_start & ~read_start_d;

    // 状态机转换
    always @(posedge clk_sd or posedge rst) begin
        if (rst)
            state <= S_IDLE;
        else
            state <= next_state;
    end

    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE:   if (read_start_posedge) next_state = S_WAIT;
            S_WAIT:   if (wait_cnt == 4'd9)   next_state = S_WRITE;
            S_WRITE:                         next_state = S_DONE;
            S_DONE:                          next_state = S_IDLE;
        endcase
    end

    // 等待计数
    always @(posedge clk_sd or posedge rst) begin
        if (rst)
            wait_cnt <= 4'd0;
        else if (state == S_WAIT)
            wait_cnt <= wait_cnt + 1'b1;
        else
            wait_cnt <= 4'd0;
    end

    // 读完成信号输出与mem内容填充
    integer i;
    always @(posedge clk_sd or posedge rst) begin
        if (rst) begin
            read_end <= 1'b0;
            for (i = 0; i < 512; i = i + 1)
                mem[i] <= 8'h0;
        end else begin
            case (state)
                S_IDLE:   read_end <= 1'b0;
                S_WRITE: begin
                    // addr = sd_src_addr + i
                    // 模拟数据 = addr[15:8] + addr[7:0] （自然溢出）
                    for (i = 0; i < 512; i = i + 1) begin
                        reg [15:0] addr;
                        addr = sd_src_addr[15:0] + i[15:0];
                        mem[i] <= addr[15:8] + addr[7:0];
                    end
                end
                S_DONE:   read_end <= 1'b1;
                default:  read_end <= 1'b0;
            endcase
        end
    end

endmodule