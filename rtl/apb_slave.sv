 // -----------------------------------------------------------------------------
 // Module      : apb_slave
 // Description : AMBA APB (v2.0) slave peripheral with 4 memory-mapped
//               32-bit registers (REG0-REG3). Implements SETUP/ACCESS
//               APB state machine per AMBA APB protocol specification.
// Author      : Abhijit Karale
// -----------------------------------------------------------------------------
module apb_slave #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32
) (
    input  logic                    pclk,
    input  logic                   presetn,
    input  logic                    psel,
    input  logic                    penable,
    input  logic                    pwrite,
    input  logic [ADDR_WIDTH-1:0]   paddr,
    input  logic [DATA_WIDTH-1:0]   pwdata,
    output logic [DATA_WIDTH-1:0]   prdata,
    output logic                    pready,
    output logic                    pslverr
    
);

    typedef enum logic [1:0] {ST_IDLE, ST_SETUP, ST_ACCESS} apb_state_t;
    apb_state_t state, next_state;

    logic [DATA_WIDTH-1:0] reg0, reg1, reg2, reg3;

    // -------------------- APB FSM --------------------
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) state <= ST_IDLE;
        else          state <= next_state;
    end

    always_comb begin
        next_state = state;
        case (state)
            ST_IDLE: begin
                if (psel && !penable) next_state = ST_SETUP;
                else                  next_state = ST_IDLE;
            end
            ST_SETUP: begin
                next_state = ST_ACCESS;
            end
            ST_ACCESS: begin
                if (psel && !penable)      next_state = ST_SETUP;
                else if (!psel)            next_state = ST_IDLE;
                else                       next_state = ST_ACCESS;
            end
            default: next_state = ST_IDLE;
        endcase
    end

    assign pready  = (state == ST_ACCESS);
    assign pslverr = (state == ST_ACCESS) && (paddr > 8'h0F); // out-of-range access flags error

    // -------------------- Register file read/write --------------------
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            reg0 <= '0; reg1 <= '0; reg2 <= '0; reg3 <= '0;
        end else if (state == ST_ACCESS && pwrite && psel && !pslverr) begin
            case (paddr[3:2])
                2'b00: reg0 <= pwdata;
                2'b01: reg1 <= pwdata;
                2'b10: reg2 <= pwdata;
                2'b11: reg3 <= pwdata;
            endcase
        end
    end

    always @(*) begin
        if (pslverr) begin
            prdata = 32'hDEAD_BEEF;
        end else begin
            case (paddr[3:2])
                2'b00: prdata = reg0;
                2'b01: prdata = reg1;
                2'b10: prdata = reg2;
                2'b11: prdata = reg3;
                default: prdata = '0;
            endcase
        end
    end

endmodule
