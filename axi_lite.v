module axi_lite
#(
    parameter C_S_AXI_ADDR_WIDTH = 32,
    parameter C_S_AXI_DATA_WIDTH = 32
)
(
    input                              s_axi_aclk,
    input                              s_axi_aresetn,
    
    // AXI slave ports
    
    // WRITE ADDRESS CHANNEL
    input   [C_S_AXI_ADDR_WIDTH-1:0]   s_axi_awaddr,
    input                              s_axi_awvalid,
    output                             s_axi_awready,


    // READ ADDRESS CHANNEL
    input   [C_S_AXI_ADDR_WIDTH-1:0]   s_axi_araddr,
    input                              s_axi_arvalid,
    output                             s_axi_arready,


    // WRITE DATA CHANNEL
    input   [C_S_AXI_DATA_WIDTH-1:0]   s_axi_wdata,
    input   [C_S_AXI_DATA_WIDTH/8-1:0] s_axi_wstrb,
    input                              s_axi_wvalid,
    output                             s_axi_wready,

    // WRITE RESPONSE CHANNEL
    input                              s_axi_bready,  // indicates that the master is ready to accept the write response from the slave
    output  [1:0]                      s_axi_bresp,   // Response Code
    output                             s_axi_bvalid,  // indicates that the slave has a valid response

    // READ DATA CHANNEL
    output   [C_S_AXI_DATA_WIDTH-1:0]  s_axi_rdata,
    output                             s_axi_rvalid,
    input                              s_axi_rready,
    output  [1:0]                      s_axi_rresp
);

localparam REGISTER_COUNT = 8;
localparam REG_INDEX_WIDTH = $clog2(REGISTER_COUNT);
reg [31:0] regfile[0:REGISTER_COUNT-1];

// Write-related signals
wire write_done;    // asserted based on the write response (e.g. writing to regfile after data arrives)

// Write address always block
// // ADDRESS WRITE CHANNEL
// input   [C_S_AXI_ADDR_WIDTH-1:0]   s_axi_awaddr,
// input                              s_axi_awvalid,
// output                             s_axi_awready,
reg reg_s_axi_awready;
assign s_axi_awready = reg_s_axi_awready;

reg [C_S_AXI_ADDR_WIDTH-1:0] latched_write_address;

reg write_addr_received;  // indicates that the write address channel is received/occupied

always@(posedge s_axi_aclk)
begin
    if(!s_axi_aresetn)
    begin
      reg_s_axi_awready <= 1'b0;
      // latched_write_address <= 0;  // if we force it to 0 every idle cycle, FF's internal state toggles continuously, wasting dynamic power
      write_addr_received <= 1'b0;
    end
    else
    begin
      reg_s_axi_awready <= 1'b0;  // to gurantee it is a single-cycle pulse, even if awvalid remains HIGH for some time
      if (!reg_s_axi_awready && s_axi_awvalid && !write_addr_received)
      begin
        reg_s_axi_awready <= 1'b1;
        latched_write_address <= s_axi_awaddr;
        write_addr_received <= 1'b1;
      end

      if (write_done)
      begin
        write_addr_received <= 1'b0;
      end
    end
end
// Write data always block

// // WRITE DATA CHANNEL
// input   [C_S_AXI_DATA_WIDTH-1:0]   s_axi_wdata,
// input   [C_S_AXI_DATA_WIDTH/8-1:0] s_axi_wstrb,
// input                              s_axi_wvalid,
// output                             s_axi_wready,

reg write_data_received;  // indicates that the write data channel is received/occupied

reg reg_s_axi_wready;
assign s_axi_wready = reg_s_axi_wready;


// map the strobe from bytes to bits
wire [31:0] wstrb_mask;
assign wstrb_mask = { {8{latched_wstrb[3]}}, {8{latched_wstrb[2]}}, {8{latched_wstrb[1]}}, {8{latched_wstrb[0]}} };

reg [C_S_AXI_DATA_WIDTH-1:0] latched_wdata;
reg [C_S_AXI_DATA_WIDTH/8-1:0] latched_wstrb;
always@(posedge s_axi_aclk)
begin
    if(!s_axi_aresetn)
    begin
      reg_s_axi_wready <= 1'b0;
      write_data_received <= 1'b0;
    end
    else
    begin
      reg_s_axi_wready <= 1'b0; // single-cycle Pulse
      if (!reg_s_axi_wready && s_axi_wvalid && !write_data_received)
      begin
        reg_s_axi_wready <= 1'b1;
        latched_wdata <= s_axi_wdata;
        latched_wstrb <= s_axi_wstrb;
        write_data_received <= 1'b1;
      end

      if (write_done)
      begin
        write_data_received <= 1'b0;
      end
    end
end

// Write response block
// // WRITE RESPONSE CHANNEL
// input                              s_axi_bready,
// output  [1:0]                      s_axi_bresp,
// output                             s_axi_bvalid,

assign write_done = s_axi_bready && reg_s_axi_bvalid; // Currently it means response-consumed, consider response-issued to enable pipelined writes
reg reg_s_axi_bvalid;
assign s_axi_bvalid = reg_s_axi_bvalid;

reg [1:0] reg_s_axi_bresp;  // right now, we only use the OKAY code (00), will extend usage later
assign s_axi_bresp = reg_s_axi_bresp;

always@(posedge s_axi_aclk)
begin
  if (!s_axi_aresetn) 
  begin
    reg_s_axi_bvalid <= 1'b0;
    reg_s_axi_bresp <= 2'b00; // Default to OKAY code
  end
  else
  begin
    if (!reg_s_axi_bvalid && write_addr_received && write_data_received)
    begin
      reg_s_axi_bvalid <= 1'b1;
      reg_s_axi_bresp <= 2'b00;
    end
    if (reg_s_axi_bvalid && s_axi_bready) // BREADY must stay HIGH for at least one full cycle
    begin
      reg_s_axi_bvalid <= 1'b0;
    end
  end
end



// Pluggable block: Write to Register File (could later be replaced by output signals which go to an external module)

wire [REG_INDEX_WIDTH-1:0] reg_write_index = latched_write_address[2 +: REG_INDEX_WIDTH];  // last two bits address a byte lane within the word

// Note: the single most important line within this whole block is the regfile writing line, which could be moved into the write response block
// But I am leaving it separately for isolation and later maintainability and readability
always @(posedge s_axi_aclk)
begin
  if (!s_axi_aresetn)
  begin
    for (int i = 0; i < REGISTER_COUNT; i++) begin
      regfile[i] <= 32'b0;
    end
  end
  else
    // Do we need to do anything here? I say no, for now at least.
  begin
    if (!reg_s_axi_bvalid && write_addr_received && write_data_received)
    begin
      regfile[reg_write_index] <= (regfile[reg_write_index] & ~wstrb_mask) | (latched_wdata & wstrb_mask);
    end
  end
end

//Read address block
// // READ ADDRESS CHANNEL
// input   [C_S_AXI_ADDR_WIDTH-1:0]   s_axi_araddr,
// input                              s_axi_arvalid,
// output                             s_axi_arready,

reg read_addr_available;
wire read_done;

reg reg_s_axi_arready;
assign s_axi_arready = reg_s_axi_arready;

reg [C_S_AXI_ADDR_WIDTH-1:0] latched_read_address;

always @(posedge s_axi_aclk)
begin
    if (!s_axi_aresetn)
    begin
      reg_s_axi_arready <= 1'b0;
      read_addr_available <= 1'b0;
    end
    else
    begin
      reg_s_axi_arready <= 1'b0;
      if (!reg_s_axi_arready && s_axi_arvalid && !read_addr_available)
      begin
        reg_s_axi_arready <= 1'b1;
        latched_read_address <= s_axi_araddr;
        read_addr_available <= 1'b1;
      end

      if (read_done)
      begin
        read_addr_available <= 1'b0;
      end
    end
end

// Read data always block
// // READ DATA CHANNEL
// output   [C_S_AXI_DATA_WIDTH-1:0]  s_axi_rdata,
// output                             s_axi_rvalid,
// input                              s_axi_rready,
// output  [1:0]                      s_axi_rresp

// note: At least for now, there is no need for a read_data_available signal because the register file is local
// If we later extend such that this module is a mere interface, and the data to be read would be brought from another module
//  then we will most likely need a read_data_available signal to indicate when that other module makes the data available to us (axi-lite)

reg [C_S_AXI_DATA_WIDTH-1:0] reg_s_axi_rdata;
reg [1:0]                    reg_s_axi_rresp;
assign s_axi_rdata = reg_s_axi_rdata;
assign s_axi_rresp = reg_s_axi_rresp;

wire [REG_INDEX_WIDTH-1:0] reg_read_index = latched_read_address[2 +: REG_INDEX_WIDTH];  // last two bits address a byte lane within the word

reg reg_s_axi_rvalid;
assign s_axi_rvalid = reg_s_axi_rvalid;

assign read_done = s_axi_rready && reg_s_axi_rvalid;

always @(posedge s_axi_aclk)
begin
  if (!s_axi_aresetn)
  begin
    reg_s_axi_rdata <= 0;
    reg_s_axi_rvalid <= 1'b0;
    reg_s_axi_rresp <= 2'b00;
  end
  else
  begin
    if (!reg_s_axi_rvalid && read_addr_available)
    begin
      reg_s_axi_rvalid <= 1'b1;
      reg_s_axi_rdata <= regfile[reg_read_index];
      reg_s_axi_rresp <= 2'b00; // OKAY for now, will extend for other error codes later
    end

    if (read_done)
    begin
      reg_s_axi_rvalid <= 1'b0;
    end
  end
end

endmodule
