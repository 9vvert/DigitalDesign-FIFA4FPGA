// 仅仅用于仿真
module fake_sdram (
    input        clk,
    input        rst,
    input  [1:0] sdram_cmd,       // 0无效，1读，2写
    input [29:0] operate_addr,    // 忽略
    input [63:0] write_data,      // 忽略
    output reg [63:0] read_data,  // 忽略
    output reg    cmd_done
);

    reg [2:0] wait_counter;      // 最多计到4
    reg [1:0] done_counter;      // 最多计到2
    reg       active;            // 标记当前是否有命令在处理

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            wait_counter <= 0;
            done_counter <= 0;
            cmd_done <= 0;
            active <= 0;
            read_data <= 64'd0;
        end else begin
            if (!active) begin
                if (sdram_cmd != 0) begin
                    // 收到新命令，开始计时
                    active <= 1;
                    wait_counter <= 0;
                    done_counter <= 0;
                    cmd_done <= 0;
                end else begin
                    cmd_done <= 0;
                end
            end else begin
                if (wait_counter < 4) begin
                    wait_counter <= wait_counter + 1;
                end else if (done_counter < 2) begin
                    cmd_done <= 1;
                    done_counter <= done_counter + 1;
                end else begin
                    // 操作完成，回到空闲
                    cmd_done <= 0;
                    active <= 0;
                end
            end
        end
    end
endmodule