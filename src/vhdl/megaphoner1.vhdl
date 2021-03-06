----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    22:30:37 12/10/2013 
-- Design Name: 
-- Module Name:    container - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use Std.TextIO.all;


-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity container is
  Port ( CLK_IN : STD_LOGIC;         
--         btnCpuReset : in  STD_LOGIC;
--         irq : in  STD_LOGIC;
--         nmi : in  STD_LOGIC;
         
         wifirx : out std_logic;
         wifitx : out std_logic;
        
         i2c1sda : inout std_logic;
         i2c1scl : inout std_logic;         

         modem1_pcm_clk_in : in std_logic;
         modem1_pcm_sync_in : in std_logic;
         modem1_pcm_data_in : in std_logic;
         modem1_pcm_data_out : out std_logic;
         modem1_uart_rx : inout std_logic;
         modem1_uart_tx : out std_logic;
         modem1_uart2_rx : inout std_logic;
         modem1_uart2_tx : out std_logic;
         
         ----------------------------------------------------------------------
         -- CIA1 ports for keyboard/joystick 
         ----------------------------------------------------------------------
--         porta_pins : inout  std_logic_vector(7 downto 0);
--         portb_pins : inout  std_logic_vector(7 downto 0);
         
         ----------------------------------------------------------------------
         -- VGA output
         ----------------------------------------------------------------------
         vga_vsync : out STD_LOGIC;
         vga_hsync : out  STD_LOGIC;
         vga_red : out  UNSIGNED (3 downto 0);
         vga_green : out  UNSIGNED (3 downto 0);
         vga_blue : out  UNSIGNED (3 downto 0);

         ----------------------------------------------------------------------
         -- HyperRAM as expansion RAM
         ----------------------------------------------------------------------
         hr_d : inout unsigned(7 downto 0);
         hr_rwds : inout std_logic;
         hr_reset : out std_logic;
         hr_clk_n : out std_logic;
         hr_clk_p : out std_logic;
         hr_cs0 : out std_logic;
         hr_cs1 : out std_logic := '1';
                  
         -------------------------------------------------------------------------
         -- Lines for the SDcard interface itself
         -------------------------------------------------------------------------
         sdReset : out std_logic := '0';  -- must be 0 to power SD controller (cs_bo)
         sdClock : out std_logic := 'Z';       -- (sclk_o)
         sdMOSI : out std_logic := 'Z';      
         sdMISO : in  std_logic;

         ----------------------------------------------------------------------
         -- Flash RAM for holding config
         ----------------------------------------------------------------------
--         QspiSCK : out std_logic;
         QspiDB : inout std_logic_vector(3 downto 0) := (others => 'Z');
         QspiCSn : out std_logic;
         
         ----------------------------------------------------------------------
         -- Analog headphone jack output
         -- (amplifier enable is on an IO expander)
         ----------------------------------------------------------------------
         headphone_left : out std_logic;
         headphone_right : out std_logic;
         
         ----------------------------------------------------------------------
         -- Debug interfaces on TE0725
         ----------------------------------------------------------------------
         led : out std_logic;

         ----------------------------------------------------------------------
         -- UART monitor interface
         ----------------------------------------------------------------------
         monitor_tx : out std_logic;
         monitor_rx : in std_logic
         
         );
end container;

architecture Behavioral of container is

  component fpgatemp is
    Generic ( DELAY_CYCLES : natural := 480 ); -- 10us @ 48 Mhz
    Port ( clk : in  STD_LOGIC;
           rst : in  STD_LOGIC;
           temp : out  STD_LOGIC_VECTOR (11 downto 0));
  end component;

  signal irq : std_logic := '1';
  signal nmi : std_logic := '1';
  signal restore_key : std_logic := '1';
  signal reset_out : std_logic := '1';
  signal cpu_game : std_logic := '1';
  signal cpu_exrom : std_logic := '1';
  
  signal buffer_vgared : unsigned(7 downto 0);
  signal buffer_vgagreen : unsigned(7 downto 0);
  signal buffer_vgablue : unsigned(7 downto 0);
  
  signal pixelclock : std_logic;
  signal cpuclock : std_logic;
  signal clock240 : std_logic;
  signal clock120 : std_logic;
  signal clock100 : std_logic;
  signal ethclock : std_logic;
  signal clock200 : std_logic;
  
  signal segled_counter : unsigned(31 downto 0) := (others => '0');

  signal slow_access_request_toggle : std_logic;
  signal slow_access_ready_toggle : std_logic;
  signal slow_access_write : std_logic;
  signal slow_access_address : unsigned(27 downto 0);
  signal slow_access_wdata : unsigned(7 downto 0);
  signal slow_access_rdata : unsigned(7 downto 0);

  signal sector_buffer_mapped : std_logic;

  
  signal vgaredignore : unsigned(3 downto 0);
  signal vgagreenignore : unsigned(3 downto 0);
  signal vgablueignore : unsigned(3 downto 0);

  signal porta_pins : std_logic_vector(7 downto 0) := (others => '1');
  signal portb_pins : std_logic_vector(7 downto 0) := (others => '1');

  signal cart_ctrl_dir : std_logic := 'Z';
  signal cart_haddr_dir : std_logic := 'Z';
  signal cart_laddr_dir : std_logic := 'Z';
  signal cart_data_dir : std_logic := 'Z';
  signal cart_phi2 : std_logic := 'Z';
  signal cart_dotclock : std_logic := 'Z';
  signal cart_reset : std_logic := 'Z';

  signal cart_nmi : std_logic := 'Z';
  signal cart_irq : std_logic := 'Z';
  signal cart_dma : std_logic := 'Z';

  signal cart_exrom : std_logic := 'Z';
  signal cart_ba : std_logic := 'Z';
  signal cart_rw : std_logic := 'Z';
  signal cart_roml : std_logic := 'Z';
  signal cart_romh : std_logic := 'Z';
  signal cart_io1 : std_logic := 'Z';
  signal cart_game : std_logic := 'Z';
  signal cart_io2 : std_logic := 'Z';

  signal cart_d : unsigned(7 downto 0) := (others => 'Z');
  signal cart_d_read : unsigned(7 downto 0) := (others => 'Z');
  signal cart_a : unsigned(15 downto 0) := (others => 'Z');
  
  ----------------------------------------------------------------------
  -- CBM floppy serial port
  ----------------------------------------------------------------------
  signal iec_clk_en : std_logic := 'Z';
  signal iec_data_en : std_logic := 'Z';
  signal iec_data_o : std_logic := 'Z';
  signal iec_reset : std_logic := 'Z';
  signal iec_clk_o : std_logic := 'Z';
  signal iec_data_i : std_logic := '1';
  signal iec_clk_i : std_logic := '1';
  signal iec_atn : std_logic := 'Z';  

  
  -- XXX We should read the real temperature and feed this to the DDR controller
  -- so that it can update timing whenever the temperature changes too much.
  signal fpga_temperature : std_logic_vector(11 downto 0) := (others => '0');

  signal dummy : std_logic_vector(2 downto 0);
  signal sawtooth_phase : integer := 0;
  signal sawtooth_counter : integer := 0;
  signal sawtooth_level : integer := 0;

  signal lcd_hsync : std_logic;
  signal lcd_vsync : std_logic;
  signal lcd_display_enable : std_logic;
  signal pal50_select : std_logic;

  -- Dummy signals for stub / not yet implemented interfaces
  signal eth_mdio : std_logic := '0';
  signal touchSDA : std_logic := '1';
  signal c65uart_rx : std_logic := '1';

  signal pin_number : integer;

  signal expansionram_read : std_logic;
  signal expansionram_write : std_logic;
  signal expansionram_rdata : unsigned(7 downto 0);
  signal expansionram_wdata : unsigned(7 downto 0);
  signal expansionram_address : unsigned(26 downto 0);
  signal expansionram_data_ready_strobe : std_logic;
  signal expansionram_busy : std_logic;

  signal dummypins : std_logic_vector(1 to 100) := (others => '0');
  
begin

  dotclock1: entity work.dotclock100
    port map ( clk_in1 => CLK_IN,
               clock80 => pixelclock, -- 80MHz
               clock40 => cpuclock, -- 40MHz
               clock50 => ethclock,
               clock200 => clock200,
               clock100 => clock100,
               clock120 => clock120,
               clock240 => clock240
               );

  fpgatemp0: fpgatemp
    generic map (DELAY_CYCLES => 480)
    port map (
      rst => '0',
      clk => cpuclock,
      temp => fpga_temperature);

  hyperram0: entity work.hyperram
    port map (
      cpuclock => cpuclock,
      clock240 => clock240,
      address => expansionram_address,
      wdata => expansionram_wdata,
      read_request => expansionram_read,
      write_request => expansionram_write,
      rdata => expansionram_rdata,
      data_ready_strobe => expansionram_data_ready_strobe,
      busy => expansionram_busy,
      hr_d => hr_d,
      hr_rwds => hr_rwds,
      hr_reset => hr_reset,
      hr_clk_n => hr_clk_n,
      hr_clk_p => hr_clk_p,
      hr_cs0 => hr_cs0,
      hr_cs1 => hr_cs1
      );
  
  slow_devices0: entity work.slow_devices
    port map (
      cpuclock => cpuclock,
      pixelclock => pixelclock,
      reset => reset_out,
      cpu_exrom => cpu_exrom,
      cpu_game => cpu_game,
      sector_buffer_mapped => sector_buffer_mapped,
      
      qspidb => qspidb,
      qspicsn => qspicsn,      
--      qspisck => '1',

      pin_number => pin_number,
      
      slow_access_request_toggle => slow_access_request_toggle,
      slow_access_ready_toggle => slow_access_ready_toggle,
      slow_access_write => slow_access_write,
      slow_access_address => slow_access_address,
      slow_access_wdata => slow_access_wdata,
      slow_access_rdata => slow_access_rdata,

      ----------------------------------------------------------------------
      -- Expansion RAM interface (upto 127MB)
      ----------------------------------------------------------------------
      expansionram_read => expansionram_read,
      expansionram_write => expansionram_write,
      expansionram_rdata => expansionram_rdata,
      expansionram_wdata => expansionram_wdata,
      expansionram_address => expansionram_address,
      expansionram_data_ready_strobe => expansionram_data_ready_strobe,
      expansionram_busy => expansionram_busy,
      
      
      ----------------------------------------------------------------------
      -- Expansion/cartridge port
      ----------------------------------------------------------------------
      cart_ctrl_dir => cart_ctrl_dir,
      cart_haddr_dir => cart_haddr_dir,
      cart_laddr_dir => cart_laddr_dir,
      cart_data_dir => cart_data_dir,
      cart_phi2 => cart_phi2,
      cart_dotclock => cart_dotclock,
      cart_reset => cart_reset,
      
      cart_nmi => cart_nmi,
      cart_irq => cart_irq,
      cart_dma => cart_dma,
      
      cart_exrom => cart_exrom,
      cart_ba => cart_ba,
      cart_rw => cart_rw,
      cart_roml => cart_roml,
      cart_romh => cart_romh,
      cart_io1 => cart_io1,
      cart_game => cart_game,
      cart_io2 => cart_io2,
      
      cart_d_in => cart_d_read,
      cart_d => cart_d,
      cart_a => cart_a
      );
  
  machine0: entity work.machine
    generic map (cpufrequency => 40)
    port map (
      pixelclock      => pixelclock,
      cpuclock        => cpuclock,
      uartclock       => cpuclock, -- Match CPU clock
      ioclock         => cpuclock, -- Match CPU clock
      clock240 => clock240,
      clock120 => clock120,
      clock40 => cpuclock,
      clock200 => clock200,
      clock50mhz      => ethclock,
      btncpureset => '1',
      reset_out => reset_out,
      irq => irq,
      nmi => nmi,
      restore_key => restore_key,
      sector_buffer_mapped => sector_buffer_mapped,

      pal50_select_out => pal50_select,
      
      -- Wire up a dummy caps_lock key on switch 8
      caps_lock_key => '1',

      fa_fire => '1',
      fa_up =>  '1',
      fa_left => '1',
      fa_down => '1',
      fa_right => '1',

      fb_fire => '1',
      fb_up => '1',
      fb_left => '1',
      fb_down => '1',
      fb_right => '1',

      fa_potx => '0',
      fa_poty => '0',
      fb_potx => '0',
      fb_poty => '0',

      f_index => '1',
      f_track0 => '1',
      f_writeprotect => '1',
      f_rdata => '1',
      f_diskchanged => '1',
      
      ----------------------------------------------------------------------
      -- CBM floppy serial port stub
      ----------------------------------------------------------------------
      iec_clk_en => iec_clk_en,
      iec_data_en => iec_data_en,
      iec_data_o => iec_data_o,
      iec_reset => iec_reset,
      iec_clk_o => iec_clk_o,
      iec_atn_o => iec_atn,
      iec_data_external => '1',
      iec_clk_external => '1',
      
      no_hyppo => '0',
      
      vsync           => vga_vsync,
      hsync           => vga_hsync,
--      lcd_vsync => lcd_vsync,
--      lcd_hsync => lcd_hsync,
--      lcd_display_enable => lcd_display_enable,
      vgared(7 downto 0)          => buffer_vgared,
      vgagreen(7 downto 0)        => buffer_vgagreen,
      vgablue(7 downto 0)         => buffer_vgablue,

      porta_pins => porta_pins,
      portb_pins => portb_pins,
      keyleft => '0',
      keyup => '0',
      
      ---------------------------------------------------------------------------
      -- IO lines to the ethernet controller (stub)
      ---------------------------------------------------------------------------
      eth_mdio => eth_mdio,
--      eth_mdc => eth_mdc,
--      eth_reset => eth_reset,
      eth_rxd => "11",
--      eth_txd => eth_txd,
--      eth_txen => eth_txen,
      eth_rxer => '1',
      eth_rxdv => '0',
      eth_interrupt => '1',
      
      -------------------------------------------------------------------------
      -- Lines for the SDcard interface itself
      -------------------------------------------------------------------------
      cs_bo => sdReset,
      sclk_o => sdClock,
      mosi_o => sdMOSI,
      miso_i => sdMISO,
      miso2_i => '1',

      -- Accelerometer (currently not connected)
      aclMISO => '1',
--      aclMOSI => aclMOSI,
--      aclSS => aclSS,
--      aclSCK => aclSCK,
      aclInt1 => '0',
      aclInt2 => '0',

      -- Microphones (currently not connected)
      micData0 => '0',
      micData1 => '0',
--      micClk => micClk,
--      micLRSel => micLRSel,

      -- Audio output
      ampPWM_l => headphone_left,
      ampPWM_r => headphone_right,
--      ampSD => ampSD,

    -- No nexys4 temperature sensor
--      tmpSDA => tmpSDA,
--      tmpSCL => tmpSCL,
      tmpInt => '0',
      tmpCT => '0',

      -- Touch screen
      touchSDA => touchSDA,
--      touchSCL => '1',
--      lcdpwm => ,

      i2c1sda => i2c1sda,
      i2c1scl => i2c1scl,
      
      -- This is for modem as PCM master:
      pcm_modem_clk_in => modem1_pcm_clk_in,
      pcm_modem_sync_in => modem1_pcm_sync_in,
        
      pcm_modem1_data_out => modem1_pcm_data_out,
      pcm_modem1_data_in => modem1_pcm_data_in,
      
      ps2data =>      '1',
      ps2clock =>     '1',

      -- Widget board interface stub
      pmod_start_of_sequence => '0',
      pmod_data_in => "1111",
      pmod_clock => '0',
      
      -- C65 UART
      uart_rx => c65uart_rx,
--      uart_tx => jclo(2),

      -- Buffered UARTs for cellular modems etc
      buffereduart_rx => modem1_uart_rx,
      buffereduart_tx => modem1_uart_tx,
      buffereduart2_rx => modem1_uart2_rx,
      buffereduart2_tx => modem1_uart2_tx,
      buffereduart_ringindicate => '0',
      
      slow_access_request_toggle => slow_access_request_toggle,
      slow_access_ready_toggle => slow_access_ready_toggle,
      slow_access_address => slow_access_address,
      slow_access_write => slow_access_write,
      slow_access_wdata => slow_access_wdata,
      slow_access_rdata => slow_access_rdata,
--      cpu_exrom => cpu_exrom,      
--      cpu_game => cpu_game,      
      -- enable/disable cartridge with sw(8)
      cpu_exrom => '1',
      cpu_game => '1',
      cart_access_count => x"00",

      fpga_temperature => fpga_temperature,

--      led(12 downto 0) => led(12 downto 0),
--      led(15 downto 13) => dummy,
      sw => (others => '0'),
      btn => (others => '0'),

      UART_TXD => monitor_tx,
      RsRx => monitor_rx
      
--      sseg_ca => sseg_ca,
--      sseg_an => sseg_an
      );
    
  process (cpuclock,clock120,cpuclock,pal50_select)
  begin
    if rising_edge(clock120) then
      -- VGA direct output
      vga_red <= buffer_vgared(7 downto 4);
      vga_green <= buffer_vgagreen(7 downto 4);
      vga_blue <= buffer_vgablue(7 downto 4);

      -- VGA out on LCD panel
--      jalo <= std_logic_vector(buffer_vgablue(7 downto 4));
--      jahi <= std_logic_vector(buffer_vgared(7 downto 4));
--      jblo <= std_logic_vector(buffer_vgagreen(7 downto 4));
--      jbhi(8) <= lcd_hsync;
--      jbhi(9) <= lcd_vsync;
--      jbhi(10) <= lcd_display_enable;
    end if;

    if rising_edge(cpuclock) then

      -- No physical keyboard
      portb_pins <= (others => '1');
      
    end if;
  end process;

  

  -- XXX Ethernet should be 250Mbit fibre port on this board  
  -- eth_clock <= cpuclock;
  
end Behavioral;
