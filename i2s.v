module i2s(
    input               rst_i,

    input               mck_i,
    input               lrck_i,
    input               bck_i,
    input               data_i,

    output              mck_o,
    output              lrck_o,
    output              bck_o,
    output              data_o,

    output reg          sdo,
    output reg          sync,
    output reg          sclk 
);

localparam  BIT = 24;
localparam  B= 0;
localparam  E = B+BIT;

localparam  IDLE = 0;
localparam  R_START = 1;
localparam  R_TRANSFER = 2;
localparam  R_DONE = 3;
localparam  L_START = 4;
localparam  L_TRANSFER = 5;
localparam  L_DONE = 6;
localparam  FLASH = 7;

assign  rstn = rst_i;
assign  mck_o = mck_i;
assign  lrck_o = lrck_i;
assign  bck_o = bck_i;
assign  data_o = data_i;

reg     lrck_r;
reg     lrck_rr;
wire    left_start;
wire    right_start;
assign  left_start = lrck_r & ~lrck_rr;
assign  right_start = ~lrck_r & lrck_rr;

always @(negedge bck_o) begin
    if (!rstn) begin
        lrck_r <= 0;
        lrck_rr <= 0;
    end
    else begin
        lrck_r <= lrck_i;
        lrck_rr <= lrck_r;
    end
end

reg             data_r;
reg[3:0]        state_r;
reg[8:0]        count;
reg[BIT-1:0]    val;
reg[BIT-1:0]    val_r;
reg[BIT-1:0]    val_rr;
reg[BIT-1:0]    l_val;
reg[BIT-1:0]    r_val;

always @(negedge bck_o) begin
    if (!rstn) begin
        state_r <= IDLE;
        count <= 0;

        val <= 1<<BIT-1;
        l_val <= 1<<BIT-1;
        r_val <= 1<<BIT-1;

        data_r <= 0;
    end
    else begin
        data_r <= data_i;

        if (right_start) begin
            state_r <= R_TRANSFER;
        end
        else if (left_start) begin
            state_r <= L_TRANSFER;
        end
        else begin
            if (state_r == IDLE) begin 
                val <= 0;
                val_r <= val;
                val_rr <= val_r;
            end
            else if (state_r == R_TRANSFER) begin
                if (count == E) begin
                    count <= 0;
                    state_r <= R_DONE;
                end
                else if (count < E) begin
                    // val <= {val, data_r};
                    val <= {val, data_i};
                    count <= count + 1;
                end
            end
            else if (state_r == R_DONE) begin
                //dithering
                r_val <= {~val[BIT-1], val[BIT-2:0]} + val_r[8:0] - val_rr[8:0];
                // r_val <= {~val[BIT-1], val[BIT-2:0]};

                state_r <= IDLE;
            end
            else if (state_r == L_TRANSFER) begin
                if (count == E) begin
                    count <= 0;
                    state_r <= L_DONE;
                end
                else if (count < E) begin
                    // val <= {val, data_r};
                    val <= {val, data_i};
                    count <= count + 1;
                end
            end
            else if (state_r == L_DONE) begin
                l_val <= {~val[BIT-1], val[BIT-2:0]} + val_r[8:0] - val_rr[8:0];
                // l_val <= {~val[BIT-1], val[BIT-2:0]};
                state_r <= IDLE;
            end
        end
    end
end

assign sclk = bck_o;

localparam  WORD = 24;
reg [3:0]       state_w;
reg [5:0]       count_w;
reg [31:0]      key;

always @(posedge bck_o) begin
    if (!rstn)  begin
        state_w <= IDLE;
        count_w <= 0;
        key <= {8'h06, val};

        sync <= 0;
        sdo <= 0;
    end
    else if (left_start) begin
        key <= {8'h08, l_val};
        state_w <= FLASH;
        sync <= 0;
    end
    else if (right_start) begin
        key <= {8'h09, r_val};
        state_w <= FLASH;
        sync <= 0;
    end
    else if (state_w == FLASH) begin
        if (count_w == WORD) begin
            state_w <= IDLE;
            count_w <= 0;
            
            sync <= 1;
            sdo <= 0;
        end
        else begin
            sync <= 0;
            sdo <= key[31 - count_w];
            count_w <= count_w + 1;
        end
    end
end

endmodule
