/********** 排序 ************/
// 根据 data_in 进行排序（从大到小排序）
// 输出：从 index[31] 到 index[0]，表示从大到小的序号
module sort(
    input logic clk,
    input logic rst,
    input logic start, // 开始排序信号
    input logic [11:0] data_in [0:31], // 输入待排序数据，固定 32 个 12 位数据
    output logic [4:0] index [0:31],   // 输出排序后的序号，从 index[31] 到 index[0]
    output logic done                  // 排序完成信号
);
    typedef enum logic [1:0] {IDLE, LOAD, SORT, DONE} state_t;
    state_t state, next_state;

    logic [11:0] array [0:31];       // 内部排序数组，存放输入数据
    logic [4:0] index_array [0:31]; // 用于记录每个数据的原始序号
    integer i, j;

    reg [1:0] done_delay_counter;
    // 排序逻辑
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            i <= 0;
            j <= 0;
            state <= IDLE; // 初始化状态
            done <= 0;
            done_delay_counter <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0; // 清除完成信号
                    if (start)begin 
                        state = LOAD;
                    end
                end
                LOAD: begin
                    for (integer k = 0; k < 32; k = k + 1) begin
                        array[k] <= data_in[k]; // 加载输入数据
                        index_array[k] <= k;    // 初始化序号
                    end
                    i <= 0;
                    j <= 1;
                    state <= SORT; // 进入排序状态
                end
                SORT: begin
                    if(array[i] > array[j])begin
                        //交换数据和序号
                        array[i] <= array[j];
                        array[j] <= array[i];
                        index_array[i] <= index_array[j];
                        index_array[j] <= index_array[i];
                    end
                    if(j < 31)begin
                        j <= j + 1;
                    end else begin
                        if(i < 30)begin
                            j <= i + 2;
                            i <= i + 1;
                        end else begin
                            for (integer k = 0; k < 32; k = k + 1) begin
                                index[k] <= index_array[k]; // 输出排序后的序号
                            end
                            state <= DONE; // 排序完成
                        end
                    end
                end
                DONE: begin
                    done <= 1; // 排序完成
                    if(done_delay_counter <= 2)begin
                        done <= 1; // 保持完成信号
                        done_delay_counter <= done_delay_counter + 1; // 延时一拍
                    end else begin
                        done <= 0; // 复位
                        done_delay_counter <= 2'b00;

                        state <= IDLE; // 返回空闲状态
                    end
                    
                    
                end
            endcase
        end
    end
endmodule