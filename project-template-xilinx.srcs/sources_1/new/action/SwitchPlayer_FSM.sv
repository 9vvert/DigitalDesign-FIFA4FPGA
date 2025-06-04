module SwichPlayer_FSM
#(parameter TOL_ANG = 9)
(
    input SwichPlayer_FSM_game_clk,
    input rst,
    input selected,
    input switch_enable,        //切换使能
    output reg switch_signal,
    output reg switch_done
);
    reg [2:0] SwitchPlayer_FSM_stat;
    reg done_delay_counter;
    reg [3:0] wait_counter;
    localparam [2:0] IDLE=0, WAIT=2, DONE=3;
    always@(posedge SwichPlayer_FSM_game_clk)begin
        if(rst)begin
            SwitchPlayer_FSM_stat <= IDLE;
            done_delay_counter <= 0;
            switch_done <= 0;
            wait_counter <= 0;
            switch_signal <= 0;
        end else begin
            if(SwitchPlayer_FSM_stat == IDLE)begin
                switch_done <= 0;
                switch_signal <= 0;
                if(switch_enable)begin
                    switch_signal<= 1;
                    SwitchPlayer_FSM_stat <= WAIT;
                    wait_counter <= 0;
                end
            end else if(SwitchPlayer_FSM_stat == WAIT)begin
                if(~selected)begin       // 自己不再被选中
                    switch_signal <= 0;
                    SwitchPlayer_FSM_stat <= DONE;
                end else begin
                    if(wait_counter >= 8)begin
                        switch_signal <= 0;
                        //超时，可能是信号没有被正确处理
                        wait_counter <= 0;
                        SwitchPlayer_FSM_stat <= DONE;
                    end else begin
                        wait_counter <= wait_counter + 1;
                    end
                end
            end else begin
                switch_done <= 1;
                if(done_delay_counter == 0)begin
                    done_delay_counter <= 1;
                end else begin
                    done_delay_counter <= 0;
                    SwitchPlayer_FSM_stat <= IDLE;
                end
            end
        end
    end

endmodule