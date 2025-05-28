/*********** sprinte_generator ***********/
// 对game传来的数据进行加工，变成可渲染的参数
// 在这里也会对跨时钟域的数据进行同步
// game_clk的周期远大于sprite_generator_ui_clk， 所以可以进行判断，如果下一个sprite_generator_ui_clk周期的数据和上一个周期相同，说明稳定，然后才可以使用
import type_declare::Render_Param_t, type_declare::BallInfo, type_declare::PlayerInfo;
import AngleLib::near_8_direction;
// [TODO] 外部调用的时候，在每一帧开始绘制的时候，会接收到32个render param，除了几个无效的外，剩余的各自对应一个图形
// [TODO] 删去render type，统一在sprite_genrator中进行计算
// 至于背景剪切，鉴于其和上一帧的图形位置有关，可以在vm_renderer中生成
module sprite_generator(
    input sprite_generator_ui_clk,
    input ui_rst,
    input [5:0] game_bg,                    //内部检测到game_bg变化后，
    input PlayerInfo player_info[9:0],
    input BallInfo ball_info,
    //实际有效的最多29个
    output Render_Param_t render_param[31:0],
    output reg [5:0] output_bg_index,
    output reg game_bg_change,
    input bg_change_done        //是否切换完成
);
    /********* background monitor **********/
    reg [1:0] bg_monitor_stat;
    localparam [1:0] IDLE=0, SNED=1, DONE=2;
    reg [5:0] curr_bg;
    reg last_game_bg;
    always@(posedge sprite_generator_ui_clk)begin
        if(ui_rst)begin
            bg_monitor_stat <= IDLE;
            curr_bg <= 29;       // 无效值，强制第一次切换背景
        end else begin
            if(bg_monitor_stat == IDLE)begin
                if( (game_bg==last_game_bg) && (game_bg != curr_bg) )begin
                    output_bg_index <= game_bg;
                    curr_bg <= game_bg;
                    bg_monitor_stat <= SNED;
                end
            end else if(bg_monitor_stat == SNED)begin
                game_bg_change <= 1;
                if(bg_change_done)begin
                    game_bg_change <= 0;
                    bg_monitor_stat <= DONE;
                end
            end else begin      //DONE
                bg_monitor_stat <= IDLE;
            end
        end
        last_game_bg <= game_bg;
    end

    PlayerInfo last_player_info[9:0];
    BallInfo last_ball_info;
    wire [10:0] stable_flag;
    localparam RENDER_SKIP=32;      //因为背景剪切要占用一半的绘制时间
    //[TODO]如果player_info是高阻态，这里stable_flag也会是高阻态
    assign stable_flag[0] = (last_player_info[0] == player_info[0]);
    assign stable_flag[1] = (last_player_info[1] == player_info[1]);
    assign stable_flag[2] = (last_player_info[2] == player_info[2]);
    assign stable_flag[3] = (last_player_info[3] == player_info[3]);
    assign stable_flag[4] = (last_player_info[4] == player_info[4]);
    assign stable_flag[5] = (last_player_info[5] == player_info[5]);
    assign stable_flag[6] = (last_player_info[6] == player_info[6]);
    assign stable_flag[7] = (last_player_info[7] == player_info[7]);
    assign stable_flag[8] = (last_player_info[8] == player_info[8]);
    assign stable_flag[9] = (last_player_info[9] == player_info[9]);
    assign stable_flag[10] = (last_ball_info == ball_info);
    always@(posedge sprite_generator_ui_clk)begin
        if(ui_rst)begin
            ;
        end else begin
            // 每周期进行记录
            last_ball_info <= ball_info;
            for(integer i=0; i<10; i=i+1)begin
                last_player_info[i] <= player_info[i];
            end
            //当稳定的时候，进行更新
            if(&stable_flag[10:0])begin //
                //进行新的计算
                // 0-31：绘制的图形； 32-63:剪切背景

                // 首先是10个人+10个辅助形状
                for(integer j=0; j<5; j=j+1)begin
                    /***************  图形 ****************/
                    //队伍1，球员  j
                    render_param[j].enable <= 1;     // 仅仅渲染一个
                    render_param[j].hpos <= player_info[j].x;
                    render_param[j].vpos <= 720 - player_info[j].y;
                    render_param[j].start_sector <= 100*near_8_direction(player_info[j].angle) + 10*player_info[j].anim_stat;
                    // render_param[j].render_priority <= 720 - player_info[j].y;
                    render_param[j].render_priority <= (j==0);
                    //队伍1，辅助 5+j
                    render_param[j+5].enable <= 1;
                    // render_param[j+5].hpos <= player_info[j].x;
                    // render_param[j+5].vpos <= 720 - player_info[j].y + 16;
                    render_param[j+5].hpos <= 128;
                    render_param[j+5].vpos <= 592;
                    render_param[j+5].start_sector <= 100*near_8_direction(player_info[j].angle) + 10*player_info[j].anim_stat;
                    render_param[j+5].render_priority <= 0;     // 初次测试，还没有辅助图形，这里暂时填为0
                    //队伍2，球员 10+j
                    render_param[j+10].enable <= 1;
                    // render_param[j+10].hpos <= player_info[j+5].x;
                    // render_param[j+10].vpos <= 720 - player_info[j+5].y;
                    render_param[j+10].hpos <= 128;
                    render_param[j+10].vpos <= 592;
                    render_param[j+10].start_sector <= 100*near_8_direction(player_info[j+5].angle) + 10*player_info[j+5].anim_stat;
                    // render_param[j+10].render_priority <= 720 - player_info[j+5].y;
                    render_param[j+10].render_priority <= 0;
                    //队伍2，辅助 15+j
                    render_param[j+15].enable <= 1;
                    // render_param[j+15].hpos <= player_info[j+5].x;
                    // render_param[j+15].vpos <= 720 - player_info[j+5].y + 16;
                    render_param[j+15].hpos <= 128;
                    render_param[j+15].vpos <= 592;
                    render_param[j+15].start_sector <= 100*near_8_direction(player_info[j+5].angle) + 10*player_info[j+5].anim_stat;
                    render_param[j+15].render_priority <= 0;
                end
                // 为了排序，剩余的全部填为0
                for(integer j=20; j < 32; j = j+1)begin
                    render_param[j].enable <= 1;
                    render_param[j].hpos <= 128;
                    render_param[j].vpos <= 592;
                    render_param[j].start_sector <= 0;
                    render_param[j].render_priority <= 0;
                end
            end
        end
    end

endmodule