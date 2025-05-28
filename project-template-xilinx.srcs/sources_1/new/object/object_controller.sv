// 管理game中最顶层的一些变量：
// 可操作者和AI球员分布 / 持球者是谁 / 球的状态 / 

module object_controller
#(parameter SELECT_INDEX1 = 1, SELECT_INDEX2 = 6)
(
    input controller_game_clk,
    input rst,

    input [9:0]tackle_signal,
    input [9:0]shoot_signal, 
    input [3:0]switch_signal[9:0],      // 正常情况下，应该为0；真正有效的信号范围是1-10

    //对球的控制信号输入，在controller模块会进行仲裁
    input ConstrainedInit in_const[9:0],
    input FreeInit in_free[9:0],
    //最终输出的对球控制信号
    output ConstrainedInit ulti_const_init,
    output FreeInit ulti_free_init,

    //人和球的状态输出
    output reg football_being_held,
    output reg [9:0] player_hold,        //保证同一时间只有一个比特为1，
    output reg [9:0] player_selected   //保证同一时间0-4和5-9各自只有一个信号为高电平
    

);
    /**************  select 控制  ****************/
    reg [3:0] curr_select1_index;     // 第一组目前的选择
    reg [3:0] curr_select2_index;     // 第二组目前的选择
    always@(posedge controller_game_clk)begin
        if(rst)begin
            curr_select1_index <= SELECT_INDEX1 - 1;
            curr_select2_index <= SELECT_INDEX2 - 1;
            for(integer i=0; i < 10; i = i+1)begin
                if( i < 5)begin //第一组
                    if(i == SELECT_INDEX1 - 1)begin
                        player_selected[i] <= 1;
                    end else begin
                        player_selected[i] <= 0;
                    end
                end else begin  //第二组
                    if(i == SELECT_INDEX2 - 1)begin
                        player_selected[i] <= 1;
                    end else begin
                        player_selected[i] <= 0;
                    end
                end
            end
        end else begin
            if(switch_signal[curr_select1_index] != 0)begin
                curr_select1_index <= switch_signal[curr_select1_index];
                for(integer j = 0; j < 5; j = j + 1)begin
                    if(j == switch_signal[curr_select1_index]-1)begin
                        player_selected[j] <= 1;
                    end else begin
                        player_selected[j] <= 0;
                    end
                end
            end
            if(switch_signal[curr_select2_index] != 0)begin
                curr_select2_index <= switch_signal[curr_select2_index];
                for(integer k = 5; k < 10; k = k + 1 )begin
                    if(k == switch_signal[curr_select2_index]-1)begin
                        player_selected[k] <= 1;
                    end else begin
                        player_selected[k] <= 0;
                    end
                end
            end
        end
    end

    /*******************  hold和shoot控制 ********************/
    reg [3:0] curr_hold_index;
    assign ulti_const_init = in_const[curr_hold_index];
    always@(posedge controller_game_clk)begin
        if(rst)begin
            football_being_held <= 0;
            player_hold <= 0;
            curr_hold_index <= 0;       // 初始值赋0，但是无效 [TODO]检查
            //刚开始球处于自由状态，应该给予一个free_init，否则会成为高阻态
            ulti_free_init.init_speed <= 0;
            ulti_free_init.init_angle <= 8'hFF;     //无效
            ulti_free_init.init_vertical_speed <= 0;
            ulti_free_init.init_vertical_signal <= 0;
        end else begin
            // 自由状态和束缚状态都有可能发生球所有权的转移
            // 但只有束缚态才有可能发生球的射出
            
            //射门优先于抢球
            if( |shoot_signal[9:0])begin
                //判断：持球者发出shoot信号才有效
                if(football_being_held && shoot_signal[curr_hold_index])begin
                    football_being_held <= 0;       // 球进入自由状态
                    ulti_free_init <= in_free[curr_hold_index];
                end
            end else if( |tackle_signal[9:0])begin
                //tackle_signal为高电平，证明已经完成了有效抢球的判定
                football_being_held <= 1;
                // for(integer j=0; j<10; j=j+1)begin
                //     //[TODO]检查是否覆盖了所有情况
                //     if(j == 0)begin
                //         if(tackle_signal[j] == 1)begin
                //             football_being_held <= 1;
                //             curr_hold_index <= 0;
                //             player_hold[0] <= 1;
                //         end else begin
                //             player_hold[0] <= 0;
                //         end
                //     end else begin
                //         if( tackle_signal[j] & (~(|tackle_signal[j-1:0])) )begin
                //             football_being_held <= 1;
                //             curr_hold_index <= j;
                //             player_hold[j] <= 1;
                //         end else begin
                //             player_hold[j] <= 0;
                //         end
                //     end
                // end

                if(|tackle_signal[4:0])begin
                    if(tackle_signal[0])begin
                        curr_hold_index <= 0;
                        player_hold = 10'b0000000001;       // 保证统一时间只有一个人持球
                    end else if(tackle_signal[1])begin
                        curr_hold_index <= 1;
                        player_hold = 10'b0000000010;       // 保证统一时间只有一个人持球
                    end else if(tackle_signal[2])begin
                        curr_hold_index <= 2;
                        player_hold = 10'b0000000100;       // 保证统一时间只有一个人持球
                    end else if(tackle_signal[3])begin
                        curr_hold_index <= 3;
                        player_hold = 10'b0000001000;       // 保证统一时间只有一个人持球
                    end else begin
                        curr_hold_index <= 4;
                        player_hold = 10'b0000010000;       // 保证统一时间只有一个人持球
                    end
                end else begin
                    if(tackle_signal[5])begin
                        curr_hold_index <= 5;
                        player_hold = 10'b0000100000;       // 保证统一时间只有一个人持球
                    end else if(tackle_signal[6])begin
                        curr_hold_index <= 6;
                        player_hold = 10'b0001000000;       // 保证统一时间只有一个人持球
                    end else if(tackle_signal[7])begin
                        curr_hold_index <= 7;
                        player_hold = 10'b0010000000;       // 保证统一时间只有一个人持球
                    end else if(tackle_signal[8])begin
                        curr_hold_index <= 8;
                        player_hold = 10'b0100000000;       // 保证统一时间只有一个人持球
                    end else begin
                        curr_hold_index <= 9;
                        player_hold = 10'b1000000000;       // 保证统一时间只有一个人持球
                    end
                end
            end
            //[TODO]检查这里是否需要写else的情况
        end
    end
endmodule