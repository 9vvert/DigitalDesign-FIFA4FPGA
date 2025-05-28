module sort(
    input logic clk,
    input logic rst,
    input logic start,
    input logic [11:0] data_in [0:31],
    output logic [4:0] index [0:31],
    output logic done
);
    typedef enum logic [1:0] {IDLE, LOAD, SORT, DONE} state_t;
    state_t state, next_state;

    logic [11:0] array [0:31];
    logic [4:0] index_array [0:31];
    integer i, j;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            done <= 0;
            i <= 0;
            j <= 0;
            for (int k = 0; k < 32; k++) begin
                array[k] <= '0;
                index_array[k] <= '0;
                index[k] <= '0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start)
                        state <= LOAD;
                end
                LOAD: begin
                    for (int k = 0; k < 32; k++) begin
                        array[k] <= data_in[k];
                        index_array[k] <= k;
                    end
                    i <= 0;
                    j <= 1;
                    state <= SORT;
                end
                SORT: begin
                    if (i < 31) begin
                        if (j < 32) begin
                            if (array[i] < array[j]) begin // 从大到小排序
                                // 用临时变量交换
                                // logic [11:0] temp_data;
                                // // logic [4:0] temp_index;
                                // temp_data = array[i];
                                // array[i] <= array[j];
                                // array[j] <= temp_data;
                                // temp_index = index_array[i];
                                // index_array[i] <= index_array[j];
                                // index_array[j] <= temp_index;
                                array[i] <= array[j];
                                array[j] <= array[i];
                                index_array[i] <= index_array[j];
                                index_array[j] <= index_array[i];
                            end
                            j <= j + 1;
                        end else begin
                            i <= i + 1;
                            j <= i + 2;
                        end
                    end else begin
                        state <= DONE;
                    end
                end
                DONE: begin
                    done <= 1;
                    // 输出 index
                    for (int k = 0; k < 32; k++) begin
                        index[k] <= index_array[k];
                    end
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule