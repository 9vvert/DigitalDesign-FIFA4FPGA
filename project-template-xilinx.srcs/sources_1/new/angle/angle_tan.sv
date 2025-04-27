module angle_tan
//  定义角度信号，有1+2+5个比特，分别代表：比特代表是否特殊(无穷),象限，
    parameter [7:0] tan_val [6:0] = {  //倍率：16
        8'd0,
        8'd1,
        8'd2,
        8'd4,
        8'd5,
        8'd7,
        8'd9,
        8'd11,
        8'd13,
        8'd15,
        8'd19,
        8'd22,
        8'd27,
        8'd34,
        8'd43,
        8'd59,
        8'd90,
        8'd182,
        8'd255,
    };
    parameter [7:0] sin_val [6:0] = {   //倍率：64
        14'd0,
        14'd5,
        14'd11,
        14'd16,
        14'd21,
        14'd27,
        14'd31,
        14'd36,
        14'd41,
        14'd45,
        14'd49,
        14'd52,
        14'd55,
        14'd58,
        14'd60,
        14'd61,
        14'd63,
        14'd63,
        14'd64,
    };
    function  [7:0] angle;  // 角度函数，输入两个点的坐标，输出角度，从点1指向点2
        input [9:0] x1;
        input [9:0] y1;
        input [9:0] x2;
        input [9:0] y2;
        begin
            if (y1 == y2) begin
                angle[7:7] = 1'b1;  // 特殊标记
                if (x1 == x2) begin 
                    angle[6:0] = 7'b1111111;    // 全为1，代表点重合
                end else if (x1 < x2) begin
                    angle[6:5] = 2'b01;  // 第二象限，代表90度
                end else begin
                    angle[6:5] = 2'b10;  // 第四象限，代表270度
                end
            end
            else if (x1 == x2) begin
                angle[7:7] = 1'b1;  
                if(y1 < y2) begin
                    angle[6:5] = 2'b00;  // 第一象限，代表0度
                end else begin
                    angle[6:5] = 2'b11;  // 第三象限，代表180度
                end
            end
            else if (x1 < x2 && y1 < y2) begin
                angle[7:7] = 1'b0;
                angle[6:5] = 2'b00;  // 第一象限
                for (i = 0; i < 18; i = i+1) begin
                    if ( (x2-x1)*tan_val[i]<=(y2-y1)*16 && (x2-x1)*tan_val[i+1]>(y2-y1)*16 ) begin
                        angle[4:0] = i;
                        break;
                    end
                end
            end
            else if (x1 < x2 && y1 > y2) begin
                angle[7:7] = 1'b0;
                angle[6:5] = 2'b01;  // 第二象限
                for (i = 0; i < 18; i = i+1) begin
                    if ( (x2-x1)*tan_val[i]<=(y1-y2)*16 && (x2-x1)*tan_val[i+1]>(y1-y2)*16 ) begin
                        angle[4:0] = i;
                        break;
                    end
                end
            end
            else if (x1 > x2 && y1 > y2) begin
                angle[7:7] = 1'b0;
                angle[6:5] = 2'b10;  // 第三象限
                for (i = 0; i < 18; i = i+1) begin
                    if ( (x1-x2)*tan_val[i]<=(y1-y2)*16 && (x1-x2)*tan_val[i+1]>(y1-y2)*16 ) begin
                        angle[4:0] = i;
                        break;
                    end
                end
            end
            else if (x1 > x2 && y1 < y2) begin
                angle[7:7] = 1'b0;
                angle[6:5] = 2'b11;  // 第四象限
                for (i = 0; i < 18; i = i+1) begin
                    if ( (x1-x2)*tan_val[i]<=(y2-y1)*16 && (x1-x2)*tan_val[i+1]>(y2-y1)*16 ) begin
                        angle[4:0] = i;
                        break;
                    end
                end
            end
        end
    endfunction
    function [6:0] angle2index;  //给定一个角度，转换为0~71的编号
        input [7:0] angle;
        begin
        //先将angle解码为0~71的编号
            if(angle[7:7] == 1'b1) begin
                if(angle[6:5] == 2'b00) begin
                    angle2index = 8'd0;
                end else if(angle[6:5] == 2'b01) begin
                    angle2index = 8'd18;
                end else if(angle[6:5] == 2'b10) begin
                    angle2index = 8'd36;
                end else if(angle[6:5] == 2'b11) begin
                    angle2index = 8'd54;
                end
            end else begin
                angle2index = (angle[4:0]+ angle[6:5]*18);
            end
        end
    endfunction

    // function [7:0] index2tan_mul_16; // 角度乘以16，输出8位数值
    //     input [7:0] angle;
    //     begin
    //     //先将angle解码为0~71的编号
    //     if(angle[7:7] == 1'b1) begin
    //         if(angle[6:5] == 2'b00) begin
    //             tan_mul_16 = 8'd0;
    //         end else if(angle[6:5] == 2'b01) begin
    //             tan_mul_16 = 8'd18;
    //         end else if(angle[6:5] == 2'b10) begin
    //             tan_mul_16 = 8'd36;
    //         end else if(angle[6:5] == 2'b11) begin
    //             tan_mul_16 = 8'd54;
    //         end
    //     end else begin
    //         tan_mul_16 = (angle[4:0]+ angle[6:5]*18);
    //     end
    //     end
    // endfunction

    function [7:0] index2sin_mul_64; // 角度乘以16，输出8位数值
        input [6:0] index;
        begin
        //先将angle解码为0~71的编号
            if(index >= 0 && index <= 18) begin
                index2sin_mul_64 = sin_val[index];
            end else if(index >= 19 && index <= 36) begin
                index2sin_mul_64 = sin_val[36-index];
            end else if(index >= 37 && index <= 54) begin
                index2sin_mul_64 = sin_val[index-36];
            end else if(index >= 55 && index <= 71) begin
                index2sin_mul_64 = sin_val[72-index];
            end else begin
                index2sin_mul_64 = 8'd0;    // 错误情况
            end
        end
    endfunction

    function [7:0] index2cos_mul_64; // 角度乘以16，输出8位数值
        input [6:0] index;
        begin
        //先将angle解码为0~71的编号
            if(index >= 0 && index <= 18) begin
                index2cos_mul_64 = sin_val[18-index];
            end else if(index >= 19 && index <= 36) begin
                index2cos_mul_64 = sin_val[index-18];
            end else if(index >= 37 && index <= 54) begin
                index2cos_mul_64 = sin_val[54-index];
            end else if(index >= 55 && index <= 71) begin
                index2cos_mul_64 = sin_val[index-54];
            end else begin
                index2cos_mul_64 = 8'd0;    // 错误情况
            end
        end
    endfunction
endmodule