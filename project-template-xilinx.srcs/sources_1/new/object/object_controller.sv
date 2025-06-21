// 管理game中最顶层的一些变量：
// 可操作者和AI球员分布 / 持球者是谁 / 球的状态 / 

module object_controller
(
    input controller_game_clk,
    input rst,
    input [1:0]pos_flag,             // 让门将持球
    input [9:0]tackle_signal,
    input [9:0]shoot_signal, 
    input [9:0]switch_signal,      // 正常情况下，应该为0；真正有效的信号范围是1-10

    //对球的控制信号输入，在controller模块会进行仲裁
    input ConstrainedInit in_const[9:0],
    input FreeInit in_free[9:0],
    // 预切换对象
    input [3:0] grp1_target,
    input [3:0] grp2_target,
    //最终输出的对球控制信号
    output ConstrainedInit ulti_const_init,
    output FreeInit ulti_free_init,

    //人和球的状态输出
    output reg football_being_held,
    output reg [9:0] player_hold,        //保证同一时间只有一个比特为1，
    output reg [9:0] player_selected,   //保证同一时间0-4和5-9各自只有一个信号为高电平
    output reg [3:0] player_selected_index1,        // 
    output reg [3:0] player_selected_index2,
    output reg [3:0] player_hold_index              // 'hF代表没有人被选中

);

    /*******************  hold和shoot控制（带延时） ********************/
reg football_delay_flag;        // 用来让being_held延时释放
reg [1:0]last_pos_flag;
reg [13:0] delay_counter;
reg [1:0]curr_flag;     //记录是1还是2
reg delay_pending;      // 延迟使能
assign ulti_const_init = in_const[ (player_hold_index<10 ? player_hold_index : 0 ) ];

    always@(posedge controller_game_clk)begin
        if(rst)begin
            football_delay_flag <= 0;
            football_being_held <= 0;
            player_hold <= 0;
            delay_counter <= 0;
            last_pos_flag <= 0;
            player_selected <= 10'b0000100001;      //起初固定选择0和5号球员
            delay_pending <= 0;
            curr_flag <= 0;
            //刚开始球处于自由状态，应该给予一个free_init，否则会成为高阻态
            ulti_free_init.init_speed <= 0;
            ulti_free_init.init_angle <= 8'h0;     //无效
            ulti_free_init.init_vertical_speed <= 0;
            ulti_free_init.init_vertical_signal <= 0;
        end else begin
            // 检测到pos_flag跳变到1或2，启动延迟
            if(!delay_pending && last_pos_flag == 0 && (pos_flag == 1 || pos_flag == 2)) begin
                delay_pending <= 1;
                delay_counter <= 0;
                curr_flag <= pos_flag;
            end

            // 延迟期间，屏蔽一切switch/tackle/shoot等信号，仅计数
            if(delay_pending) begin
                if(delay_counter < 14'd2000) begin
                    delay_counter <= delay_counter + 1;
                end else begin
                    // 延迟完成，赋值持球状态
                    football_being_held <= 1;
                    if(curr_flag == 1) begin
                        player_hold <= 10'b0000010000;
                        player_selected[4:0] <= 5'b10000;
                        player_selected[9:5] <= player_selected[9:5]; // 保持高5位不变
                    end else if(curr_flag == 2) begin
                        player_hold <= 10'b1000000000;
                        player_selected[9:5] <= 5'b10000;
                        player_selected[4:0] <= player_selected[4:0]; // 保持低5位不变
                    end
                    delay_pending <= 0; // 退出延迟
                end
            end else begin
                // 正常流程
                //信号优先级：射门 > 抢断 > 切换
                if( |shoot_signal[9:0])begin
                    //判断：持球者发出shoot信号才有效
                    if(football_delay_flag)begin
                        football_delay_flag <= 0;
                        football_being_held <= 0;
                        player_hold[ (player_hold_index<10 ? player_hold_index : 0 ) ] <= 0;
                    end else if(football_being_held && shoot_signal[ (player_hold_index<10 ? player_hold_index : 0 ) ])begin
                        ulti_free_init <= in_free[ (player_hold_index<10 ? player_hold_index : 0 ) ];
                        if(player_hold_index == 4)begin
                            player_selected[4:0] <= 5'b00001;    //选中0
                        end else if(player_hold_index == 9)begin
                            player_selected[9:5] <= 5'b00001;    //选中5
                        end
                        football_delay_flag <= 1;   //置为1，在下一个周期会将being_held拉低
                    end
                    // 这里必须让footabll_being_held延迟一个周期再转变，否则无法及时设置ulti_free_init
                end else if( |tackle_signal[9:0])begin
                    //tackle_signal为高电平，证明已经完成了有效抢球的判定
                    football_being_held <= 1;

                    if(|tackle_signal[4:0])begin
                        if(tackle_signal[0])begin
                            player_selected[4:0] <= 5'b00001;
                            player_hold <= 10'b0000000001;
                        end else if(tackle_signal[1])begin
                            player_selected[4:0] <= 5'b00010;
                            player_hold <= 10'b0000000010;
                        end else if(tackle_signal[2])begin
                            player_selected[4:0] <= 5'b00100;
                            player_hold <= 10'b0000000100;
                        end else if(tackle_signal[3])begin
                            player_selected[4:0] <= 5'b01000;
                            player_hold <= 10'b0000001000;
                        end else begin
                            player_selected[4:0] <= 5'b10000;
                            player_hold <= 10'b0000010000;
                        end
                    end else begin
                        if(tackle_signal[5])begin
                            player_selected[9:5] <= 5'b00001;
                            player_hold <= 10'b0000100000;
                        end else if(tackle_signal[6])begin
                            player_selected[9:5] <= 5'b00010;
                            player_hold <= 10'b0001000000;
                        end else if(tackle_signal[7])begin
                            player_selected[9:5] <= 5'b00100;
                            player_hold <= 10'b0010000000;
                        end else if(tackle_signal[8])begin
                            player_selected[9:5] <= 5'b01000;
                            player_hold <= 10'b0100000000;
                        end else begin
                            player_selected[9:5] <= 5'b10000;
                            player_hold <= 10'b1000000000;
                        end
                    end
                end else begin
                    if(~player_hold[3:0])begin          // 只允许非持球者切换，忽略持球方的切人请求
                        if(switch_signal[player_selected_index1])begin
                            player_selected[player_selected_index1] <= 0;
                            player_selected[grp1_target] <= 1;              
                        end
                    end
                    if(~player_hold[8:5])begin
                        if(switch_signal[player_selected_index2])begin
                            player_selected[player_selected_index2] <= 0;
                            player_selected[grp2_target] <= 1;              
                        end
                    end
                end
            end
            last_pos_flag <= pos_flag;
        end
    end


    /************* 输出辅助值 ******************/
    always_comb begin
        player_hold_index = player_hold[0] ? 0:
                            player_hold[1] ? 1:
                            player_hold[2] ? 2:
                            player_hold[3] ? 3:
                            player_hold[4] ? 4:
                            player_hold[5] ? 5:
                            player_hold[6] ? 6:
                            player_hold[7] ? 7:
                            player_hold[8] ? 8:
                            player_hold[9] ? 9:
                            4'hF;       // 无效值

        player_selected_index1 = player_selected[0] ? 0:
                                 player_selected[1] ? 1:
                                 player_selected[2] ? 2:
                                 player_selected[3] ? 3:
                                 player_selected[4] ? 4:
                                 4'hF;       // 无效值
        player_selected_index2 = player_selected[5] ? 5:
                                player_selected[6] ? 6:
                                player_selected[7] ? 7:
                                player_selected[8] ? 8:
                                player_selected[9] ? 9:
                                4'hF;       // 无效值                         
    end
endmodule