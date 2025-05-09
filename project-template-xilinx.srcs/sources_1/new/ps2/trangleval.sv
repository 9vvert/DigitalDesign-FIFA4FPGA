// 一些关于三角函数值的操作
// 因为无法直接存储小数，因此采用定点的方法，正弦和余弦乘以256， 正切乘以16
// 
// 第一位0为正，1为负；剩余的9比特用来表示数据；另外后9位全1表示为无穷(1FF:正无穷； 3FF:负无穷)
// 

// 给定一个角度，返回处理后的角度 
// 前2个比特是象限(0-17, 18-35,36-53, 54-71)；后面
function automatic[1:0] quadrant(
    input [7:0] ang
);
    
endfunction

//给定一个0~17的值，返回正弦值*12
function automatic [9:0] sin(
    input [7:0] ang
);
    case (ang)
    8'd0 : sin = 10'd0;
    8'd1 : sin = 10'd1;
    8'd2 : sin = 10'd2;
    8'd3 : sin = 10'd3;
    8'd4 : sin = 10'd4;
    8'd5 : sin = 10'd5;
    8'd6 : sin = 10'd6;
    8'd7 : sin = 10'd7;
    8'd8 : sin = 10'd8;
    8'd9 : sin = 10'd8;
    8'd10 : sin = 10'd9;
    8'd11 : sin = 10'd10;
    8'd12 : sin = 10'd10;
    8'd13 : sin = 10'd11;
    8'd14 : sin = 10'd11;
    8'd15 : sin = 10'd12;
    8'd16 : sin = 10'd12;
    8'd17 : sin = 10'd12;
    default: sin = 10'd257;  //错误
    endcase
endfunction

function automatic [9:0] cos(
    input [7:0] ang
);
    case (ang)
        8'd0: cos = 10'd12;
        8'd1: cos = 10'd11;
        8'd2: cos = 10'd11;
        8'd3: cos = 10'd11;
        8'd4: cos = 10'd11;
        8'd5: cos = 10'd10;
        8'd6: cos = 10'd10;
        8'd7: cos = 10'd9;
        8'd8: cos = 10'd9;
        8'd9: cos = 10'd8;
        8'd10: cos = 10'd7;
        8'd11: cos = 10'd6;
        8'd12: cos = 10'd6;
        8'd13: cos = 10'd5;
        8'd14: cos = 10'd4;
        8'd15: cos = 10'd3;
        8'd16: cos = 10'd2;
        8'd17: cos = 10'd1;
        default: cos = 10'd256;  //错误
    endcase
endfunction

function automatic [9:0] tan(
    input [7:0] ang
);
    case (ang)
        8'd0: tan = 10'd0;
        8'd1: tan = 10'd1;
        8'd2: tan = 10'd3;
        8'd3: tan = 10'd4;
        8'd4: tan = 10'd6;
        8'd5: tan = 10'd7;
        8'd6: tan = 10'd9;
        8'd7: tan = 10'd11;
        8'd8: tan = 10'd13;
        8'd9: tan = 10'd16;
        8'd10: tan = 10'd19;
        8'd11: tan = 10'd23;
        8'd12: tan = 10'd28;
        8'd13: tan = 10'd34;
        8'd14: tan = 10'd44;
        8'd15: tan = 10'd60;
        8'd16: tan = 10'd90;
        8'd17: tan = 10'd183;
        default: tan = 10'd257;  //错误
    endcase
endfunction


// function automatic [7:0] arctan(
//     input [11:0] y,
//     input [11:0] x,
//     input [9:0] tan_val
// );
//     reg [7:0] angle;
//     begin
//         if (tan_val > 16) begin  // 10-18
//             if (tan_val <= 19) begin
//                 angle = 10;
//             end else if (tan_val <= 23) begin
//                 angle = 11;
//             end else if (tan_val <= 28) begin
//                 angle = 12;
//             end else if (tan_val <= 34) begin
//                 angle = 13;
//             end else if (tan_val <= 44) begin
//                 angle = 14;
//             end else if (tan_val <= 60) begin
//                 angle = 15;
//             end else if (tan_val <= 90) begin
//                 angle = 16;
//             end else if (tan_val <= 183) begin
//                 angle = 17;
//             end else begin
//                 angle = 18;
//             end
//         end else begin  // 0-9
//             if (tan_val == 0) begin
//                 angle = 0;
//             end else if (tan_val <= 1) begin
//                 angle = 1;
//             end else if (tan_val <= 3) begin
//                 angle = 2;
//             end else if (tan_val <= 4) begin
//                 angle = 3;
//             end else if (tan_val <= 6) begin
//                 angle = 4;
//             end else if (tan_val <= 7) begin
//                 angle = 5;
//             end else if (tan_val <= 9) begin
//                 angle = 6;
//             end else if (tan_val <= 11) begin
//                 angle = 7;
//             end else if (tan_val <= 13) begin
//                 angle = 8;
//             end else begin
//                 angle = 9;
//             end
//         end
//     end
//     arctan = angle;
// endfunction

// 将 位置拓展到16位
function automatic [7:0] arctan(
    input [15:0] y,
    input [15:0] x
);
    reg [7:0] angle;
    begin
        if (16 * y > 16 * x) begin  // 10-18
            if (16 * y <= 19 * x) begin
                angle = 10;
            end else if (16 * y <= 23 * x) begin
                angle = 11;
            end else if (16 * y <= 28 * x) begin
                angle = 12;
            end else if (16 * y <= 34 * x) begin
                angle = 13;
            end else if (16 * y <= 44 * x) begin
                angle = 14;
            end else if (16 * y <= 60 * x) begin
                angle = 15;
            end else if (16 * y <= 90 * x) begin
                angle = 16;
            end else if (16 * y <= 183 * x) begin
                angle = 17;
            end else begin
                angle = 18;
            end
        end else begin  // 0-9
            if (16 * y == 0 * x) begin
                angle = 0;
            end else if (16 * y <= 1 * x) begin
                angle = 1;
            end else if (16 * y <= 3 * x) begin
                angle = 2;
            end else if (16 * y <= 4 * x) begin
                angle = 3;
            end else if (16 * y <= 6 * x) begin
                angle = 4;
            end else if (16 * y <= 7 * x) begin
                angle = 5;
            end else if (16 * y <= 9 * x) begin
                angle = 6;
            end else if (16 * y <= 11 * x) begin
                angle = 7;
            end else if (16 * y <= 13 * x) begin
                angle = 8;
            end else begin
                angle = 9;
            end
        end
    end
    arctan = angle;
endfunction



// 给定A和B，返回从A到B引线的角度
// 必须确保A和B不重合
function automatic[7:0] vec2angle(
    input [15:0] x1,
    input [15:0] y1,
    input [15:0] x2,
    input [15:0] y2
);
    automatic logic[15:0] delta_x = (x1 > x2) ? (x1-x2) : (x2-x1);
    automatic logic[15:0] delta_y = (y1 > y2) ? (y1-y2) : (y2-y1);
    
    if(x1 > x2) begin
        if(y1 > y2) begin
            //第三象限
            vec2angle = 8'd36 + arctan(delta_x, delta_y);   // delta_x / delta_y
        end else if(y1 < y2) begin
            //第四象限
            vec2angle = 8'd54 + arctan(delta_y, delta_x);   // delta_x / delta_y
            if(vec2angle >= 8'd72) begin        //这里有可能会算出72
                vec2angle = vec2angle - 8'd72;
            end
        end else begin
            vec2angle = 8'd54;
        end
    end else if(x1 < x2) begin
        if(y1 > y2) begin
            //第二象限
            vec2angle = 8'd18 + arctan(delta_y, delta_x);   // delta_x / delta_y
        end else if(y1 < y2) begin
            //第一象限
            vec2angle = arctan(delta_x, delta_y);   // delta_x / delta_y
        end else begin
            vec2angle = 8'd54;
        end
    end else begin
        if(y1 > y2) begin
            vec2angle = 8'd36;
        end else begin
            vec2angle = 8'd0;
        end
    end

endfunction

// //给定一个点A， 角度x，半径r，给出目标点B
// function automatic[11:0] radiation_by_angle(
//     input [15:0] x1,
//     input [15:0] y1,
//     input [7:0] angle,
//     input [15:0] r
// );


// endfunction

// //给定两个点A,B，半径r，给出目标点C，和radiation_by_angle的区别是，这里传递两个点之间的坐标，能够减少中间计算带来的误差
// function automatic[11:0] radiation_by_pos(
//     input [15:0] x1,
//     input [15:0] y1,
//     input [15:0] x2,
//     input [15:0] y2,
//     input [15:0] r
// );


// endfunction