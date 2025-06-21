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
    input sprite_generator_game_clk,
    input rst,
    input sprite_generator_ui_clk,
    input ui_rst,
    input [5:0] game_bg,                    //内部检测到game_bg变化后，
    input PlayerInfo player_info[9:0],
    input BallInfo ball_info,
    input [2:0] shoot_level[9:0],    // 蓄力条
    input [3:0] player_hold_index,  
    //实际有效的最多29个
    input [3:0] points_1,
    input [3:0] points_2,
    output Render_Param_t render_param[31:0],
    output reg [5:0] output_bg_index,
    output reg game_bg_change,
    input bg_change_done        //是否切换完成
);
    /********* background monitor **********/
    reg [1:0] bg_monitor_stat;
    Render_Param_t tmp_render_param[31:0];
    localparam [1:0] IDLE=0, SNED=1, DONE=2;
    reg [5:0] curr_bg;
    reg last_game_bg;
    reg toggle;

    always@(posedge sprite_generator_game_clk)begin
        if(rst)begin
            toggle <= 0;
            bg_monitor_stat <= IDLE;
            curr_bg <= 29;       // 无效值，强制第一次切换背景
        end else begin
            // 首先是10个人+10个辅助形状
            toggle <= ~toggle;
            for(integer j=0; j<5; j=j+1)begin
                /***************  图形 ****************/
                //队伍1，球员  j
                tmp_render_param[j].enable <= 1;
                tmp_render_param[j].hpos <= player_info[j].x;
                tmp_render_param[j].vpos <= 720 - player_info[j].y;
                tmp_render_param[j].start_sector <= 100*near_8_direction(player_info[j].angle) + 10*player_info[j].anim_stat;
                tmp_render_param[j].render_priority <= player_info[j].y;
                //队伍1，辅助 5+j
                tmp_render_param[j+5].enable <= 1;
                tmp_render_param[j+5].hpos <= player_info[j].x;
                tmp_render_param[j+5].vpos <= 720 - player_info[j].y + 13;      // 本来是16，但是感觉13效果更好
                tmp_render_param[j+5].start_sector <= player_info[j].selected ? (2000 + 10*player_info[j].angle) :
                                                player_info[j].target ? 2810 : 2800;
                tmp_render_param[j+5].render_priority <= 720;  
                
                //队伍2，球员 10+j
                tmp_render_param[j+10].enable <= 1;
                tmp_render_param[j+10].hpos <= player_info[j+5].x;
                tmp_render_param[j+10].vpos <= 720 - player_info[j+5].y;
                tmp_render_param[j+10].start_sector <= 1000 + 100*near_8_direction(player_info[j+5].angle) + 10*player_info[j+5].anim_stat;
                tmp_render_param[j+10].render_priority <= player_info[j+5].y;
                //队伍2，辅助 15+j
                tmp_render_param[j+15].enable <= 1;
                tmp_render_param[j+15].hpos <= player_info[j+5].x;
                tmp_render_param[j+15].vpos <= 720 - player_info[j+5].y + 13;
                tmp_render_param[j+15].start_sector <= player_info[j+5].selected ? (3000 + 10*player_info[j+5].angle):
                                                player_info[j+5].target ? 3810 : 3800;
                tmp_render_param[j+15].render_priority <= 720;
                
            end
            //足球
            tmp_render_param[20].enable <= 1;
            tmp_render_param[20].hpos <= ball_info.x;
            tmp_render_param[20].vpos <= 720 - ball_info.y - (ball_info.z>>1) +16;  //中心校准：16
            tmp_render_param[20].start_sector <= 5000 + 10 * ball_info.anim_stat;   // 必须保证anim_stat取值为1-3
            tmp_render_param[20].render_priority <= ball_info.y;

            tmp_render_param[21].enable <= (player_hold_index < 10) & shoot_level[(player_hold_index<10?player_hold_index:0)] != 0; //这里进行变换，因为超过数组范围的话会让tmp_render_param变成高阻态，从而无法触发渲染
            tmp_render_param[21].hpos <= player_info[player_hold_index].x;
            tmp_render_param[21].vpos <= 720 - player_info[player_hold_index].y - 24;
            tmp_render_param[21].start_sector <= 4000 + 10 *shoot_level[(player_hold_index<10?player_hold_index:0)] ;   // 必须保证anim_stat取值为1-3
            tmp_render_param[21].render_priority <= player_info[player_hold_index].y;

            tmp_render_param[22].enable <= 1;
            tmp_render_param[22].hpos <= 485;
            tmp_render_param[22].vpos <= 75;
            tmp_render_param[22].start_sector <= 4100 + 10 *points_1 ;   // 必须保证anim_stat取值为1-3
            tmp_render_param[22].render_priority <= 100;

            tmp_render_param[23].enable <= 1;
            tmp_render_param[23].hpos <= 785;
            tmp_render_param[23].vpos <= 75;
            tmp_render_param[23].start_sector <= 4100 + 10 *points_2 ;   // 必须保证anim_stat取值为1-3
            tmp_render_param[23].render_priority <= 100;

            // 为了排序，剩余的全部填为0
            for(integer j=24; j < 32; j = j+1)begin
                tmp_render_param[j].enable <= 0;
                tmp_render_param[j].hpos <= 128;
                tmp_render_param[j].vpos <= 592;
                tmp_render_param[j].start_sector <= 0;
                tmp_render_param[j].render_priority <= 0;
            end


            // 背景判断
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

    reg toggle1, toggle2, toggle3;
    reg last_toggle;
    reg [31:0]stable_counter;
    always@(posedge sprite_generator_ui_clk)begin
        if(ui_rst)begin
            last_toggle <= 0;
            stable_counter <= 0;   
        end else begin
            toggle1 <= toggle;
            toggle2 <= toggle1;
            toggle3 <= toggle2;
            if(toggle3 == toggle2)begin
                if(stable_counter > 1000)begin
                    if(toggle3 != last_toggle)begin
                        for(integer i=0;i<32;i =i+1)begin
                            render_param[i] <= tmp_render_param[i];
                        end
                    end
                    last_toggle <= toggle3;
                end else begin
                    stable_counter <= stable_counter + 1;
                end
            end else begin
                stable_counter <= 0;
            end
        end
    end 
endmodule