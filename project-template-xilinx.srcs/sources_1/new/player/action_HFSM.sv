// 可以完成很多模块，然后用仲裁器进行选择
// 最终目标：向外输出角速度、加速度、动画状态，以实现动态控制
module action_HFSM(
    input game_clk,
    input rst,
    input ready,    //进入动作
    output reg done,    //完成动作，用于释放action_mutex
    
    //当前状态
    input [15:0] pos_x,
    input [15:0] pos_y,
    input [15:0] pos_z,
    input [7:0] speed,
    input [7:0] angle,
    //命令
    input [7:0] left_angle,
    input [7:0] right_angle,
    input [5:0] action_cmd,
    //
    output reg A_enable,
    output reg A_signal,
    output reg W_enable,
    output reg W_signal,
    output reg anmi_stat,
    
    
    output reg action_message        // 比如进行抢断时，是否判定成功
    

);
    reg [5:0] player_stat;  //真正用于逻辑的状态寄存器
    reg [7:0] turn_parameter;   //在一个转向turn中，用于标记是否有新的转向
    reg [7:0] current_speed_max;    //当前的速度阈值，如果超过这个速度，需要先减速才能完成下一步的操作
    wire [7:0] rel_angle = rel_angle_val(angle, left_angle);
    wire [1:0] rel_pos = rel_angle_pos(angle, left_angle);
    reg FSM_restart;        //自动机重置标记，当设置为1的时候，再从起始状态执行自动机
    localparam IDLE = 8'd0, TURN = 8'd1, TACKLE = 8'd2, SHOOT = 8'd3;
    always @(posedge game_clk) begin
        if(rst) begin
            turn_parameter <= 8'hFF;
        end else begin
            case(player_stat)
                IDLE:
                    // 在这个状态下，如果速度不满，进行加速(弥补了转向后的减速惩罚)
                    A_enable <= 1'b1;   // 保持加速度（加速度器中会进行约束）
                    A_signal <= 1'b0;
                    W_enable <= 1'b0;
                    case (action_cmd)
                        6'd0: player_stat <= IDLE;
                        6'd1: player_stat <= SHOOT;     //直塞
                        6'd2: player_stat <= TACKLE;
                        default: player_stat <= IDLE;
                    endcase
                TURN:   //转向状态
                    //[TODO] 排查angle的使用过程中是否都对8'hFF进行了特殊处理
                    case (action_cmd)
                        6'd0: player_stat <= TURN;  // 和IDLE中不同，这里默认应该保持当前状态
                        6'd1: player_stat <= SHOOT;     //直塞
                        6'd2: player_stat <= TACKLE;
                        default: player_stat <= TURN;
                    endcase
                    if(left_angle == 8'hFF || left_angle == angle) begin           //在使用angle的时候，一定要注意排除特殊的“无方向”情况
                        player_stat <= IDLE;
                        W_enable <= 1'b0;
                        A_enable <= 1'b0;
                    end else begin
                        if(left_angle != turn_parameter) begin
                            turn_parameter <= left_angle;   //更新目标  
                            if(rel_angle <= 9) begin    // 没有减速惩罚
                                current_speed_max = 3;
                            end else if(rel_angle <= 18) begin
                                current_speed_max = 2;
                            end else if(rel_angle <= 27) begin
                                current_speed_max = 1;
                            end else begin              // 这种情况下，只有先减速到0再开始转向
                                current_speed_max = 0;
                            end
                        end else begin                      //似乎只有稳定后才能
                            if(speed > current_speed_max) begin
                                A_enable <= 1'b1;
                                A_signal <= 1'b1;   // 减速
                            end else begin      // 减速达到目标，开始转向
                                A_enable <= 1'b0; 
                                if(rel_pos == 2'd2) begin   //已经重合
                                    player_stat <= IDLE;
                                    W_enable <= 1'b0;
                                end else if(rel_pos == 2'd0) begin
                                    W_enable <= 1'b1;
                                    W_signal <= 1'b1;   // 逆时针
                                end else begin
                                    W_enable <= 1'b1;
                                    W_signal <= 1'b0;
                                end
                            end
                        end
                    end
                TACKLE:
                    //
                SHOOT:
                    //
                default: player_stat <= IDLE;
            endcase
        end
    end

endmodule