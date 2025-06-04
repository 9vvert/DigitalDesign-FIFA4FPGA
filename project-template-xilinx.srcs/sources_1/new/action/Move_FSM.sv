/********** Move_FSM  ************/
// 最基本的移动控制模块
module Move_FSM
// 平衡，减少对HOLDER的惩罚
#(parameter HOLDER_MAX_V=4, FREE_MAX_V=4, CHARGE_MAX_V=6)
(
    output reg [31:0] debug_number,
    input Move_FSM_game_clk,
    input rst,
    // 不需要使能，因为Move_FSM只是给出控制加速度、角速度的建议，是否使用还要靠上层的HFSM仲裁
    input hold,                     //是否持球，这回影响最大速度
    input sprint,                   //是否按下冲刺按键
    input [7:0] left_angle,
    input PlayerInfo self_info,
    output MoveControl basic_ctrl,
    output reg [3:0] move_anim_stat
);
    import AngleLib::*;
    wire [1:0] rel_pos;
    wire [7:0] rel_angle;
    assign rel_pos = rel_angle_pos(self_info.angle, left_angle);
    assign rel_angle = rel_angle_val(self_info.angle, left_angle);
    always@(posedge Move_FSM_game_clk)begin
        if(rst)begin
            basic_ctrl.A_enable <= 0;
            basic_ctrl.W_enable <= 0;
            debug_number <= 0;
        end else begin
            debug_number[31:24] <= left_angle;
            if(left_angle == 8'hFF)begin
                basic_ctrl.W_enable <= 0;       //禁止角速度
                if(self_info.speed > 0)begin
                    basic_ctrl.A_enable <= 1;
                    basic_ctrl.A_signal <= 1;   //减速
                end
            end else begin
                //////////////////// 持球者 ////////////////////
                if(hold)begin   // 持球者，无法冲刺，而且最大奔跑速度被限定为3
                    if(self_info.speed >HOLDER_MAX_V)begin
                        basic_ctrl.W_enable <= 0;
                        basic_ctrl.A_enable <= 1;
                        basic_ctrl.A_signal <= 1;   //减速
                    end else begin
                        //角度控制
                        if(rel_pos == 0)begin   // 左侧
                            basic_ctrl.W_enable <= 1;
                            basic_ctrl.W_signal <= 1;   //逆时针
                        end else if(rel_pos == 2)begin  //右侧
                            basic_ctrl.W_enable <= 1;
                            basic_ctrl.W_signal <= 0;   //顺时针
                        end else if(rel_pos == 0)begin  //重合  // TODO这里后续是否可以换成其它？
                            basic_ctrl.W_enable <= 0;
                        end else begin  //
                            basic_ctrl.W_enable <= 1;
                            basic_ctrl.W_signal <= 0;   // 0/1均可
                        end
                        if(rel_angle < 9)begin
                            // 这种情况角度已经比较接近，允许加速
                            //速度控制
                            if(self_info.speed > HOLDER_MAX_V)begin
                                basic_ctrl.A_enable <= 1;
                                basic_ctrl.A_signal <= 1;  // 刚冲刺完可能有这种情况，需要先减速
                            end if(self_info.speed < HOLDER_MAX_V)begin    // 加速的情况比减速要更严格一些，为了防止出现在边缘抖动的情况
                                if(rel_angle < 7)begin          
                                    basic_ctrl.A_enable <= 1;
                                    basic_ctrl.A_signal <= 0;
                                end else begin
                                    basic_ctrl.A_enable <= 0;
                                end
                            end else begin
                                basic_ctrl.A_enable <= 0;
                            end 
                        end else if(rel_angle < 18)begin
                            if(self_info.speed > HOLDER_MAX_V-1)begin
                                basic_ctrl.A_enable <= 1;
                                basic_ctrl.A_signal <= 1;
                            end else begin
                                basic_ctrl.A_enable <= 0;
                            end 
                        end else if(rel_angle < 27)begin
                            if(self_info.speed > HOLDER_MAX_V-2)begin
                                basic_ctrl.A_enable <= 1;
                                basic_ctrl.A_signal <= 1;
                            end else begin
                                basic_ctrl.A_enable <= 0;
                            end 
                        end else begin
                            if(self_info.speed > HOLDER_MAX_V-3)begin
                                basic_ctrl.A_enable <= 1;
                                basic_ctrl.A_signal <= 1;
                            end else begin
                                basic_ctrl.A_enable <= 0;
                            end 
                        end
                    end
                //////////////////// 非持球者 ////////////////////
                end else begin  
                    if(sprint)begin //冲刺键
                        basic_ctrl.W_enable <= 0;      //停止转向
                        if(self_info.speed < CHARGE_MAX_V)begin
                            basic_ctrl.A_enable <= 1;
                            basic_ctrl.A_signal <= 0;   //加速
                        end else begin
                            basic_ctrl.A_enable <= 0;
                        end
                    end else begin
                        if(self_info.speed >FREE_MAX_V)begin
                            basic_ctrl.W_enable <= 0;
                            basic_ctrl.A_enable <= 1;
                            basic_ctrl.A_signal <= 1;   //减速
                        end else begin
                            //角度控制
                            if(rel_pos == 0)begin   // 左侧
                                basic_ctrl.W_enable <= 1;
                                basic_ctrl.W_signal <= 1;   //逆时针
                            end else if(rel_pos == 2)begin  //右侧
                                basic_ctrl.W_enable <= 1;
                                basic_ctrl.W_signal <= 0;   //顺时针
                            end else if(rel_pos == 0)begin  //重合
                                basic_ctrl.W_enable <= 0;
                            end else begin  //正对的情况，任意选择一个方向都行
                                basic_ctrl.W_enable <= 1;
                                basic_ctrl.W_signal <= 0;   // 0/1均可
                            end
                            if(rel_angle < 9)begin
                                // 这种情况角度已经比较接近，允许加速
                                //速度控制
                                if(self_info.speed > FREE_MAX_V)begin
                                    basic_ctrl.A_enable <= 1;
                                    basic_ctrl.A_signal <= 1;  // 刚冲刺完可能有这种情况，需要先减速
                                end if(self_info.speed < FREE_MAX_V)begin    
                                    if(rel_angle < 7)begin              // 加速的情况比减速要更严格一些，为了防止出现在边缘抖动的情况
                                        basic_ctrl.A_enable <= 1;
                                        basic_ctrl.A_signal <= 0;
                                    end else begin
                                        basic_ctrl.A_enable <= 0;
                                    end
                                end else begin
                                    basic_ctrl.A_enable <= 0;
                                end 
                            end else if(rel_angle < 18)begin
                                if(self_info.speed > FREE_MAX_V-1)begin
                                    basic_ctrl.A_enable <= 1;
                                    basic_ctrl.A_signal <= 1;
                                end else begin
                                    basic_ctrl.A_enable <= 0;
                                end
                            end else if(rel_angle < 27)begin
                                if(self_info.speed > FREE_MAX_V-2)begin
                                    basic_ctrl.A_enable <= 1;
                                    basic_ctrl.A_signal <= 1;
                                end else begin
                                    basic_ctrl.A_enable <= 0;
                                end 
                            end else begin
                                if(self_info.speed > FREE_MAX_V-3)begin
                                    basic_ctrl.A_enable <= 1;
                                    basic_ctrl.A_signal <= 1;
                                end else begin
                                    basic_ctrl.A_enable <= 0;
                                end 
                            end
                        end
                    end
                end
            end
        end
    end


    /************** 动画状态机  *****************/
    reg [9:0] anim_counter;
    reg [9:0] anim_T;       //切换需要的时间
    reg [1:0] anim_switch_stat;
    reg special_flag;       // 2-1-2-3，用于区分下一个是1还是3
    always@(posedge Move_FSM_game_clk)begin
        if(rst)begin
            anim_counter <= 0;
            anim_T <= 1000;
            move_anim_stat <= 2;
            anim_switch_stat <= 0;
            special_flag <= 0;
        end else begin
            if(anim_switch_stat == 0)begin
                if(self_info.speed == 0)begin
                    move_anim_stat <= 2;
                    anim_counter <= 0;
                    anim_switch_stat <= 0;
                    special_flag <= 0;
                end else begin
                    anim_counter <= 0;
                    anim_switch_stat <= 1;  //进入计数状态
                    //这里的周期并不是严格按照比例
                    if(self_info.speed == 1)begin
                        anim_T <= 500;
                    end else if(self_info.speed == 2)begin
                        anim_T <= 400;
                    end else if(self_info.speed == 3)begin
                        anim_T <= 300;
                    end else if(self_info.speed == 4)begin
                        anim_T <= 200;
                    end else if(self_info.speed == 5)begin
                        anim_T <= 100;
                    end else begin
                        anim_T <= 75;
                    end
                end
            end else begin
                if(anim_counter >= anim_T)begin
                    anim_counter <= 0;
                    anim_switch_stat <= 0;
                    if(move_anim_stat == 2)begin
                        if(special_flag)begin
                            move_anim_stat <= 1;
                        end else begin
                            move_anim_stat <= 3;
                        end
                        special_flag <= ~special_flag;
                    end else if(move_anim_stat == 1 || move_anim_stat ==3)begin
                        move_anim_stat <= 2;
                    end else begin              // 
                        move_anim_stat <= 2;
                    end
                end else begin
                    anim_counter <= anim_counter + 1;
                end
            end
        end
    end
endmodule