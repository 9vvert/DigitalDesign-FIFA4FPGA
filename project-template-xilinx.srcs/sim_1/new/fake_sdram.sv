// fake_sdram.sv
// 仅实现如下外部接口，模拟SDRAM读写行为。
// 读数据时，输出数据64bit，每个8bit部分内容为(operate_addr[15:8] + operate_addr[7:0])，自然溢出。
// 初始化完成信号init_calib_complete会等待一段时间后拉高。

module fake_sdram (
    input clk_100m,
    output wire        ui_clk,
    output reg        ui_clk_sync_rst,
    output wire        init_calib_complete,  // 延时后为1
    input  wire [1:0]  sdram_cmd,           // 0无效，1读取，2写入
    input  wire [29:0] operate_addr,        // 地址
    input  wire [63:0] write_data,
    output reg  [63:0] read_data,
    output reg         cmd_done             // 命令完成信号，拉高1周期
);


    assign ui_clk = clk_100m;

    // 延迟初始化完成：假设500个周期后拉高
    reg [8:0] calib_cnt = 9'd0;
    reg calib_done = 1'b0;
    assign init_calib_complete = calib_done;

    always @(posedge ui_clk) begin
        if(calib_cnt >= 9 && calib_cnt <= 12)begin
            ui_clk_sync_rst <= 1;
        end else begin
            ui_clk_sync_rst <= 0;
        end
        if (!calib_done) begin
            if (calib_cnt < 9'd100)
                calib_cnt <= calib_cnt + 1'b1;
            else
                calib_done <= 1'b1;
        end
    end

    // 状态机
    typedef enum logic [1:0] {
        S_IDLE = 2'd0,
        S_READ = 2'd1,
        S_WRITE = 2'd2,
        S_DONE = 2'd3
    } state_t;
    state_t state = S_IDLE;
    reg [1:0] delay_cnt = 2'd0;
    reg [15:0] addr16;
    reg [7:0] val;
    // 状态机流程
    always @(posedge ui_clk) begin
        if (!calib_done) begin
            // 初始化没好时不响应命令
            state <= S_IDLE;
            cmd_done <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    cmd_done <= 1'b0;
                    if (sdram_cmd == 2'd1) begin
                        addr16 <= operate_addr[15:0];
                        val <= operate_addr[15:8] + operate_addr[7:0] + operate_addr[23:16];
                        state <= S_READ;
                    end else if (sdram_cmd == 2'd2) begin
                        state <= S_WRITE;
                    end else begin
                        state <= S_IDLE;
                    end
                end
                S_READ: begin
                    // 生成模拟数据
                    
                    
                    read_data <= {8'(val), 8'(val+1), 8'(val+2), 8'(val+3), 8'(val+4), 8'(val+5), 8'(val+6), 8'(val+7)};
                    cmd_done <= 1'b1;
                    state <= S_DONE;
                end
                S_WRITE: begin
                    // 不处理实际写入，仅模拟流程
                    cmd_done <= 1'b1;
                    state <= S_DONE;
                end
                S_DONE: begin
                    if (delay_cnt == 2'd0) begin
                        delay_cnt <= delay_cnt + 1'b1;
                    end else begin
                        cmd_done <= 1'b0;
                        delay_cnt <= 2'd0;
                        state <= S_IDLE;
                    end
                end
                default: state <= S_IDLE;
            endcase
        end
    end

endmodule