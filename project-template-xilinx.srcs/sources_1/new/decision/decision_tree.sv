// 决策树，先用自然语言描述
import type_declare::*;
import ai_package::*;
import field_package::*; 
module decision_tree
//初始化参数：队伍已经门将编号; (team0:4 ,team1:9 为固定的门将)
#(parameter TEAM=0)       
(
    input ai_game_clk,
    input rst,
    //外界的信息
    input [3:0]hold_index,              // 为 'hF代表没有任何人持球
    input [3:0]selected_index,  // 外界要保证传入的selected_index是自己组的
    input PlayerInfo player_info[9:0],
    input BallInfo ball_info,

    output Decision_t decision[4:0],
    // 参数
    output reg [1:0] forward_mode[3:0],     // 应对不同情况
    output reg [7:0] area_angle1,
    output reg [7:0] area_angle2

);
    import LineLib::*, AngleLib::*, TrianglevalLib::*;

    /////////////////////// 真正的决策指令生成
    wire no_holder;
    wire self_hold;
    assign no_holder = (hold_index == 'hF);
    assign self_hold = (hold_index >= 0 && hold_index <= 4 && TEAM==0) || (hold_index >= 5 && hold_index <= 9 && TEAM==1);

    reg AD_flag;        // 进攻/防守
    reg [5:0] decision_stat;    //决策树状态
    // 
    localparam [5:0] CHECK_SELECT=0, DELAY=1, LOAD_INFO=2, CHECK_AD=3,  CAL_DISTANCE=4, SORT=5, 
        ALLOCATE_D=6, GEN_PARAM_D=7, ALLOCATE_A=8, GEN_PARAM_A=9, SLEEP=10, KEEPER_CHECK=11;

    // 第一阶段
    PlayerInfo free_player_info [2:0];
    reg [3:0] free_player_index [2:0];        // 3名AI分配普通角色，加上固定编号的门将
    // 第二阶段
    reg [31:0] free_player_ball_dis[2:0];
    reg [3:0] sorted_dis_index[2:0];  // 按照距离球的距离，从小到大排序

    reg [9:0] sleep_counter;  //延时计数器

    // 
    reg [3:0] last_selected_index;
    always@(posedge ai_game_clk)begin
        if(rst)begin
            decision[0] <= (selected_index==0+5*TEAM) ? C_DISABLE : C_IDLE;
            decision[1] <= (selected_index==1+5*TEAM) ? C_DISABLE : C_IDLE;
            decision[2] <= (selected_index==2+5*TEAM) ? C_DISABLE : C_IDLE;
            decision[3] <= (selected_index==3+5*TEAM) ? C_DISABLE : C_IDLE;
            decision[4] <= D_KEEPER;   // 门将，站着不动
            AD_flag <= 0;   //默认防守，这时候会派人抢球
            last_selected_index <= 'hF;
            sleep_counter <= 0;
            free_player_info[0] <= player_info[0];      // 防止被优化
            free_player_info[1] <= player_info[0];
            free_player_info[2] <= player_info[0];
            forward_mode[0] <= 0;
            forward_mode[1] <= 0;
            forward_mode[2] <= 0;
            forward_mode[3] <= 0;

        end else begin
            case(decision_stat)
                CHECK_SELECT:begin
                    last_selected_index <= selected_index;      // 新一轮的选择
                    if(selected_index != last_selected_index)begin
                        if(selected_index==0+5*TEAM)begin
                            free_player_index[0]=1+5*TEAM;
                            free_player_index[1]=2+5*TEAM;
                            free_player_index[2]=3+5*TEAM;
                        end else if(selected_index==1+5*TEAM)begin
                            free_player_index[0]=0+5*TEAM;
                            free_player_index[1]=2+5*TEAM;
                            free_player_index[2]=3+5*TEAM;
                        end else if(selected_index==2+5*TEAM)begin
                            free_player_index[0]=0+5*TEAM;
                            free_player_index[1]=1+5*TEAM;
                            free_player_index[2]=3+5*TEAM;
                        end else begin
                            free_player_index[0]=0+5*TEAM; 
                            free_player_index[1]=1+5*TEAM; 
                            free_player_index[2]=2+5*TEAM;
                        end
                    end
                    if(hold_index == 4 || hold_index == 9)begin
                        decision_stat <= KEEPER_CHECK;
                    end else begin
                        decision_stat <= LOAD_INFO;
                    end
                end
                KEEPER_CHECK:begin      // 门将持球，不进行动作
                    decision[0] <= C_IDLE;
                    decision[1] <= C_IDLE;
                    decision[2] <= C_IDLE;
                    decision[3] <= C_IDLE;
                    sleep_counter <= 0;
                    decision_stat <= SLEEP;
                end
                LOAD_INFO:begin
                    free_player_info[0] <= player_info[free_player_index[0]];
                    free_player_info[1] <= player_info[free_player_index[1]];
                    free_player_info[2] <= player_info[free_player_index[2]];
                    decision_stat <= CHECK_AD;
                end
                CHECK_AD:begin      //根据当前的状态
                    if(AD_flag)begin        //本身是进攻，
                        if(~self_hold & ~no_holder)begin
                            AD_flag <= 0;   //敌人持球，进入防守状态
                        end else begin
                            AD_flag <= 1;  //继续进攻
                        end
                    end else begin
                        if(self_hold)begin
                            AD_flag <= 1;
                        end else begin
                            AD_flag <= 0;
                        end
                    end
                    decision_stat <= CAL_DISTANCE;
                end
                CAL_DISTANCE:begin      // 不论何时，决策划分依据的都是人和球的距离
                    free_player_ball_dis[0] <= distance(free_player_info[0].x,
                        free_player_info[0].y,
                        ball_info.x,
                        ball_info.y
                    );
                    free_player_ball_dis[1] <= distance(free_player_info[1].x,
                        free_player_info[1].y,
                        ball_info.x,
                        ball_info.y
                    );
                    free_player_ball_dis[2] <= distance(free_player_info[2].x,
                        free_player_info[2].y,
                        ball_info.x,
                        ball_info.y
                    );
                    decision_stat <= SORT;
                end
                SORT:begin
                    // 按照距离球的距离，从小到大排序
                    if(free_player_ball_dis[0] <= free_player_ball_dis[1] && free_player_ball_dis[0]<= free_player_ball_dis[2])begin
                        sorted_dis_index[0] <= free_player_index[0];
                        if(free_player_ball_dis[1] <= free_player_ball_dis[2])begin
                            sorted_dis_index[1] <= free_player_index[1];
                            sorted_dis_index[2] <= free_player_index[2];
                        end else begin
                            sorted_dis_index[1] <= free_player_index[2];
                            sorted_dis_index[2] <= free_player_index[1];
                        end
                    end else if(free_player_ball_dis[1] <= free_player_ball_dis[0] && free_player_ball_dis[1]<= free_player_ball_dis[2])begin
                        sorted_dis_index[0] <= free_player_index[1];
                        if(free_player_ball_dis[0] <= free_player_ball_dis[2])begin
                            sorted_dis_index[1] <= free_player_index[0];
                            sorted_dis_index[2] <= free_player_index[2];
                        end else begin
                            sorted_dis_index[1] <= free_player_index[2];
                            sorted_dis_index[2] <= free_player_index[0];
                        end
                    end else begin
                        sorted_dis_index[0] <= free_player_index[2];
                        if(free_player_ball_dis[1] <= free_player_ball_dis[0])begin
                            sorted_dis_index[1] <= free_player_index[1];
                            sorted_dis_index[2] <= free_player_index[0];
                        end else begin
                            sorted_dis_index[1] <= free_player_index[0];
                            sorted_dis_index[2] <= free_player_index[1];
                        end
                    end
                    if(AD_flag)begin
                        decision_stat <= ALLOCATE_A;
                    end else begin
                        decision_stat <= ALLOCATE_D;
                    end
                    
                end
                ALLOCATE_A:begin
                    if(no_holder)begin
                        decision[sorted_dis_index[0]-5*TEAM] = D_TACKLE;  
                        decision[sorted_dis_index[1]-5*TEAM] = D_TACKLE; 
                        decision[sorted_dis_index[2]-5*TEAM] = A_DEFEND;  //最远的一个人是DEFEND
                    end else begin
                        decision[sorted_dis_index[0]-5*TEAM] = A_FORWARD; 
                        decision[sorted_dis_index[1]-5*TEAM] = A_FORWARD;   
                        decision[sorted_dis_index[2]-5*TEAM] = A_DEFEND;    
                    end
                    forward_mode[sorted_dis_index[0]-5*TEAM] <= 1;
                    forward_mode[sorted_dis_index[1]-5*TEAM] <= 2;
                    sleep_counter <= 0;
                    decision_stat <= SLEEP;
                end
                ALLOCATE_D:begin
                    decision[sorted_dis_index[0]-5*TEAM] = D_TACKLE;
                    if(no_holder)begin
                        decision[sorted_dis_index[1]-5*TEAM] = D_TACKLE;
                        decision[sorted_dis_index[2]-5*TEAM] = D_TACKLE;
                    end else begin
                        decision[sorted_dis_index[1]-5*TEAM] = D_AREA_INTERCEPT; //使用FORWARD，但是为了拦截
                        decision[sorted_dis_index[2]-5*TEAM] = A_FORWARD;
                    end
                    forward_mode[sorted_dis_index[2]-5*TEAM] <= 0;
                    
                    decision_stat <= GEN_PARAM_D;
                end
                GEN_PARAM_D:begin
                    // 生成AREA_INTEGERCEPT的参数，对D_TACKLE无效，
                    if(TEAM==0)begin
                        area_angle1 = vec2angle(player_info[hold_index].x, player_info[hold_index].y,
                            RIGHT_NET_X1, RIGHT_ATTACK_Y2);
                        area_angle2 = vec2angle(player_info[hold_index].x, player_info[hold_index].y,
                            RIGHT_NET_X1, RIGHT_ATTACK_Y1);
                    end else begin
                        area_angle1 = vec2angle(player_info[hold_index].x, player_info[hold_index].y,
                            LEFT_NET_X2, LEFT_ATTACK_Y2);
                        area_angle2 = vec2angle(player_info[hold_index].x, player_info[hold_index].y,
                            LEFT_NET_X2, LEFT_ATTACK_Y1);   //顺序：先TOP再BOTTOM
                    end
                    sleep_counter <= 0;
                    decision_stat <= SLEEP;
                end
                SLEEP:begin
                    if(sleep_counter < 100)begin
                        sleep_counter <= sleep_counter + 1;
                    end else begin
                        sleep_counter <= 0;
                        decision_stat <= CHECK_SELECT;  //重新开始
                    end
                end
                default: decision_stat <= SLEEP;  //默认状态
            endcase
        end
    end
endmodule