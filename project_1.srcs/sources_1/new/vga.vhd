library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;


entity vga is
    port(
        clk              : in  std_logic;                          -- 100 MHz
        rst_n            : in  std_logic;                          -- low active reset
        general_state    : in  std_logic_vector(1 downto 0); --总状态切�?
        difficulty_state : in  std_logic_vector(1 downto 0); --难度切换
        move_state       : in  std_logic_vector(4 downto 0);--蛇朝向切�?
        random_x         : in  std_logic_vector(4 downto 0);--食物随机x
        random_y         : in  std_logic_vector(4 downto 0);--食物随机y

        O_red            : out std_logic_vector(3 downto 0);--vga红色
        O_green          : out std_logic_vector(3 downto 0);--vga绿色
        O_blue           : out std_logic_vector(3 downto 0);--vga蓝色

        snake_x          : out std_logic_vector(199 downto 0);
        snake_y          : out std_logic_vector(199 downto 0);
        snake_length     : out std_logic_vector(9 downto 0);

        O_hs             : out std_logic;--vga行同�?
        flag_isdead      : out std_logic;--蛇死亡判�?
        O_vs             : out std_logic --vga场同�?
    );
end vga;

architecture Behavioral of vga is
    --===============  常量映射 ===============
    constant start      : std_logic_vector(1 downto 0) := "00";--�?始菜�?
    constant diff_menu  : std_logic_vector(1 downto 0) := "01";--选择难度菜单
    constant game_start : std_logic_vector(1 downto 0) := "10";--初始
    constant gaming     : std_logic_vector(1 downto 0) := "11";--游戏进行菜单

    constant hard : std_logic_vector(1 downto 0) := "00";--�?
    constant mid  : std_logic_vector(1 downto 0) := "01";--�?
    constant easy : std_logic_vector(1 downto 0) := "10";--�?

    constant length_init : unsigned(9 downto 0) := to_unsigned(3,10);--蛇初始长�?
    constant headx_init  : unsigned(9 downto 0) := to_unsigned(340,10);--蛇头初始x坐标
    constant heady_init  : unsigned(8 downto 0) := to_unsigned(240,9);--蛇头初始y坐标

    constant stop       : std_logic_vector(4 downto 0) := "00001";--初始停止状�??
    constant face_up    : std_logic_vector(4 downto 0) := "00010";--向上状�??
    constant face_down  : std_logic_vector(4 downto 0) := "00100";--向下状�??
    constant face_left  : std_logic_vector(4 downto 0) := "01000";--向左状�??
    constant face_right : std_logic_vector(4 downto 0) := "10000";--向右状�??

    constant square_length : integer := 20;--界面�?
    constant square_width  : integer := 24;--界面�?

  --===============  VGA 时序常量 �?640 * 480�?===============
    constant C_H_SYNC_PULSE   : integer := 96;
    constant C_H_BACK_PORCH   : integer := 48;
    constant C_H_ACTIVE_TIME  : integer := 640;
    constant C_H_FRONT_PORCH  : integer := 16;
    constant C_H_LINE_PERIOD  : integer := 800;

    constant C_V_SYNC_PULSE   : integer := 2;
    constant C_V_BACK_PORCH   : integer := 33;
    constant C_V_ACTIVE_TIME  : integer := 480;
    constant C_V_FRONT_PORCH  : integer := 10;
    constant C_V_FRAME_PERIOD : integer := 525;

    constant h_before : integer := C_H_SYNC_PULSE + C_H_BACK_PORCH;
    constant h_after  : integer := C_H_LINE_PERIOD - C_H_FRONT_PORCH;
    constant v_before : integer := C_V_SYNC_PULSE + C_V_BACK_PORCH;
    constant v_after  : integer := C_V_FRAME_PERIOD - C_V_FRONT_PORCH;

    --===============  内部信号 ===============
    signal R_h_cnt       : unsigned(11 downto 0);-- 行时序计数器
    signal R_v_cnt       : unsigned(11 downto 0);-- 列时序计数器
    signal W_active_flag : std_logic;--刷新标志，为1时rgb数据显示

    signal stay_cnt  : unsigned(29 downto 0);--蛇在每一格停留时长计数器
    signal interval  : unsigned(29 downto 0);--蛇在每一格停留时�?

    signal flag_printnew : std_logic;--指定难度时间间隔，用于刷新屏�?




    --=== 颜色寄存�? ===
    signal red_r   : std_logic_vector(3 downto 0);
    signal green_r : std_logic_vector(3 downto 0);
    signal blue_r  : std_logic_vector(3 downto 0);

    --=============== 工具函数（用于切片，把存储的蛇的位置数据转换为单元格数据�? ===============
    function slice10(vec : std_logic_vector; idx : natural) return unsigned is
        variable lo : integer := idx*10;
    begin
        return unsigned(vec(lo+9 downto lo));
    end function;

    function slice10_y(vec : std_logic_vector; idx : natural) return unsigned is
        variable lo : integer := idx*10;
    begin
        return unsigned(vec(lo+9 downto lo));
    end function;

begin
    ------------------------------------------------------------------
    -- 行计数器
    ------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '1' then
            R_h_cnt <= (others => '0');
        elsif rising_edge(clk) then
            if R_h_cnt = C_H_LINE_PERIOD-1 then
                R_h_cnt <= (others => '0');
            else
                R_h_cnt <= R_h_cnt + 1;
            end if;
        end if;
    end process;

    O_hs <= '0' when (R_h_cnt < C_H_SYNC_PULSE) else '1';

    ------------------------------------------------------------------
    -- 列计数器
    ------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '1' then
            R_v_cnt <= (others => '0');
        elsif rising_edge(clk) then
            if R_v_cnt = C_V_FRAME_PERIOD-1 then
                R_v_cnt <= (others => '0');
            elsif R_h_cnt = C_H_LINE_PERIOD-1 then
                R_v_cnt <= R_v_cnt + 1;
            end if;
        end if;
    end process;

    O_vs <= '0' when (R_v_cnt < C_V_SYNC_PULSE) else '1';

    ------------------------------------------------------------------
    -- 有效区标�?
    ------------------------------------------------------------------
    W_active_flag <= '1' when 
    (to_integer(R_h_cnt) >= h_before)  and
    (to_integer(R_h_cnt) <  h_after)   and
    (to_integer(R_v_cnt) >= v_before)  and
    (to_integer(R_v_cnt) <  v_after)   else '0';

    ------------------------------------------------------------------
    -- pause 计数�? (stay_cnt) 以及 flag_printnew
    ------------------------------------------------------------------
    W_active_flag <= '1' when 
         (to_integer(R_h_cnt) >= h_before)  and
         (to_integer(R_h_cnt) <  h_after)   and
         (to_integer(R_v_cnt) >= v_before)  and
         (to_integer(R_v_cnt) <  v_after)   else '0';

    ------------------------------------------------------------------
    -- pause 计数�? (stay_cnt) 以及 flag_printnew
    ------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '1' then
            stay_cnt <= (others => '0');
        elsif rising_edge(clk) then
            if general_state = game_start then
                stay_cnt <= (others => '0');
            elsif (general_state = gaming) and (move_state /= stop) then
                if stay_cnt = interval - 1 then
                    stay_cnt <= (others => '0');
                else
                    stay_cnt <= stay_cnt + 1;
                end if;
            end if;
        end if;
    end process;

    flag_printnew <= '1' when stay_cnt = interval - 1 else '0';

    ------------------------------------------------------------------
    -- 难度对应 interval
    ------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '1' then
            interval <= to_unsigned(20_000_000, 30); -- 0.8 s
        elsif rising_edge(clk) then
            if (general_state = diff_menu) then
                case difficulty_state is
                    when easy => interval <= to_unsigned(20_000_000,30); --0.8
                    when mid  => interval <= to_unsigned(10_000_000,30); --0.4
                    when hard => interval <= to_unsigned(5_000_000 ,30); --0.2
                    when others => null;
                end case;
            end if;
        end if;
    end process;




    ------------------------------------------------------------------
    -- 蛇死亡判定
    ------------------------------------------------------------------
    process(clk, rst_n)
        -- function body_hit(headx, heady : unsigned(9 downto 0);
        --                   bodx, body : std_logic_vector;
        --                   len : unsigned) return boolean is
        -- begin
        --     -- 由于是逐项硬编码，这里直接在下面过程里展开即可
        --     return false;
        -- end function;
    begin
        if rst_n = '0' then
            isdead_r <= '0';
        elsif rising_edge(clk) then
            if general_state = game_start then
                isdead_r <= '0';
            elsif isdead_r = '0' then
                -- 边界
                if (slice10(snake_x_r,0) < to_unsigned(0,10)) or
                   (slice10(snake_x_r,0) > to_unsigned(640-square_length,10)) or
                   (slice10_y(snake_y_r,0) < to_unsigned(0,9)) or
                   (slice10_y(snake_y_r,0) > to_unsigned(480-square_width,9)) then
                    isdead_r <= '1';
                -- 蛇头碰身体（硬编码 19 次）
                elsif (slice10(snake_x_r,0) = slice10(snake_x_r,1) and
                       slice10_y(snake_y_r,0) = slice10_y(snake_y_r,1)) then
                    isdead_r <= '1';
                elsif (slice10(snake_x_r,0) = slice10(snake_x_r,2) and
                       slice10_y(snake_y_r,0) = slice10_y(snake_y_r,2)) then
                    isdead_r <= '1';
                elsif (slice10(snake_x_r,0) = slice10(snake_x_r,3) and
                        slice10_y(snake_y_r,0) = slice10_y(snake_y_r,3)) then
                    isdead_r <= '1';
                elsif (slice10(snake_x_r,0) = slice10(snake_x_r,4) and
                        slice10_y(snake_y_r,0) = slice10_y(snake_y_r,4)) then
                    isdead_r <= '1';
                elsif (slice10(snake_x_r,0) = slice10(snake_x_r,5) and
                        slice10_y(snake_y_r,0) = slice10_y(snake_y_r,5)) then
                    isdead_r <= '1';
                elsif (slice10(snake_x_r,0) = slice10(snake_x_r,6) and
                        slice10_y(snake_y_r,0) = slice10_y(snake_y_r,6)) then
                    isdead_r <= '1';
                elsif (slice10(snake_x_r,0) = slice10(snake_x_r,7) and
                        slice10_y(snake_y_r,0) = slice10_y(snake_y_r,7)) then
                    isdead_r <= '1';
                elsif (slice10(snake_x_r,0) = slice10(snake_x_r,8) and
                        slice10_y(snake_y_r,0) = slice10_y(snake_y_r,8)) then
                    isdead_r <= '1';
                elsif (slice10(snake_x_r,0) = slice10(snake_x_r,9) and
                        slice10_y(snake_y_r,0) = slice10_y(snake_y_r,9)) then
                    isdead_r <= '1';
                elsif (slice10(snake_x_r,0) = slice10(snake_x_r,10) and
                        slice10_y(snake_y_r,0) = slice10_y(snake_y_r,10)) then
                    isdead_r <= '1';
                elsif (slice10(snake_x_r,0) = slice10(snake_x_r,11) and
                        slice10_y(snake_y_r,0) = slice10_y(snake_y_r,11)) then
                    isdead_r <= '1';
                elsif (slice10(snake_x_r,0) = slice10(snake_x_r,12) and
                        slice10_y(snake_y_r,0) = slice10_y(snake_y_r,12)) then
                    isdead_r <= '1';
                elsif (slice10(snake_x_r,0) = slice10(snake_x_r,13) and
                        slice10_y(snake_y_r,0) = slice10_y(snake_y_r,13)) then
                    isdead_r <= '1';
                elsif (slice10(snake_x_r,0) = slice10(snake_x_r,14) and
                        slice10_y(snake_y_r,0) = slice10_y(snake_y_r,14)) then
                    isdead_r <= '1';
                elsif (slice10(snake_x_r,0) = slice10(snake_x_r,15) and
                        slice10_y(snake_y_r,0) = slice10_y(snake_y_r,15)) then
                    isdead_r <= '1';
                elsif (slice10(snake_x_r,0) = slice10(snake_x_r,16) and
                        slice10_y(snake_y_r,0) = slice10_y(snake_y_r,16)) then
                    isdead_r <= '1';
                elsif (slice10(snake_x_r,0) = slice10(snake_x_r,17) and
                        slice10_y(snake_y_r,0) = slice10_y(snake_y_r,17)) then
                    isdead_r <= '1';
                elsif (slice10(snake_x_r,0) = slice10(snake_x_r,18) and
                        slice10_y(snake_y_r,0) = slice10_y(snake_y_r,18)) then
                    isdead_r <= '1';
                elsif (slice10(snake_x_r,0) = slice10(snake_x_r,19) and
                        slice10_y(snake_y_r,0) = slice10_y(snake_y_r,19)) then
                    isdead_r <= '1';
                elsif (slice10(snake_x_r,0) = slice10(snake_x_r,20) and
                        slice10_y(snake_y_r,0) = slice10_y(snake_y_r,20)) then
                    isdead_r <= '1';                    
                end if;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------
    -- 蛇身移动  
    ------------------------------------------------------------------
    process(clk, rst_n)
        -- 便捷变量
        variable head_x  : unsigned(9 downto 0);
        variable head_y  : unsigned(9 downto 0);
    begin
        if rst_n = '0' then
            -- 初始化首 3 节
            snake_x_r(9 downto 0)    <= std_logic_vector(headx_init);
            snake_y_r(9 downto 0)    <= std_logic_vector(heady_init);
            snake_x_r(19 downto 10)  <= std_logic_vector(headx_init - square_length);
            snake_y_r(19 downto 10)  <= std_logic_vector(heady_init);
            snake_x_r(29 downto 20)  <= std_logic_vector(headx_init - 2*square_length);
            snake_y_r(29 downto 20)  <= std_logic_vector(heady_init);
            snake_x_r(199 downto 30) <= (others => '0');
            snake_y_r(199 downto 30) <= (others => '0');
        elsif rising_edge(clk) then
            if general_state = game_start then
                snake_x_r(9 downto 0)    <= std_logic_vector(headx_init);
                snake_y_r(9 downto 0)    <= std_logic_vector(heady_init);
                snake_x_r(19 downto 10)  <= std_logic_vector(headx_init - square_length);
                snake_y_r(19 downto 10)  <= std_logic_vector(heady_init);
                snake_x_r(29 downto 20)  <= std_logic_vector(headx_init - 2*square_length);
                snake_y_r(29 downto 20)  <= std_logic_vector(heady_init);
                snake_x_r(199 downto 30) <= (others => '0');
                snake_y_r(199 downto 30) <= (others => '0');

            elsif move_state = stop then
                null; -- 保持不动

            elsif (flag_printnew = '1') and (general_state = gaming) then
                -- 取当前头坐标
                head_x := slice10(snake_x_r,0);
                head_y := slice10_y(snake_y_r,0);

                -- 根据方向更新
                case move_state is
                    when face_right => head_x := head_x + square_length;
                    when face_left  => head_x := head_x - square_length;
                    when face_up    => head_y := head_y - square_width;
                    when face_down  => head_y := head_y + square_width;
                    when others     => null;
                end case;

                -- 整体移位：从尾到头
                snake_x_r(199 downto 10) <= snake_x_r(189 downto 0);
                snake_y_r(199 downto 10) <= snake_y_r(189 downto 0);

                -- 写新头
                snake_x_r(9 downto 0) <= std_logic_vector(head_x);
                snake_y_r(9 downto 0) <= std_logic_vector(head_y);
            end if;
        end if;
    end process;

    ------------------------------------------------------------------
    -- 颜色生成（对应 Verilog mega case）
    ------------------------------------------------------------------
    process(clk, rst_n)
        -- 辅助布尔信号
        variable issnake        : boolean;
        variable h_issnake      : boolean;
        variable v_issnake      : boolean;
        variable issnake_green  : boolean;
        variable issnake_blue   : boolean;
        variable issnake_pink   : boolean;
        variable isfood         : boolean;
        variable h_isfood       : boolean;
        variable v_isfood       : boolean;
    begin
        if rst_n = '0' then
            red_r   <= (others => '0');
            green_r <= (others => '0');
            blue_r  <= (others => '0');
        elsif rising_edge(clk) then
            if W_active_flag = '0' then
                red_r   <= (others => '0');
                green_r <= (others => '0');
                blue_r  <= (others => '0');

            else
                ------------------------------------------------------------------
                -- 在这里把 issnake / isfood 等布尔量按照 Verilog 方式完整展开
                ------------------------------------------------------------------
                h_issnake := 
                (R_h_cnt >= h_before + unsigned(snake_x_r(9 downto 0)) and R_h_cnt < h_before + unsigned(snake_x_r(9 downto 0)) + square_length) or
                (R_h_cnt >= h_before + unsigned(snake_x_r(19 downto 10)) and R_h_cnt < h_before + unsigned(snake_x_r(19 downto 10)) + square_length) or
                (R_h_cnt >= h_before + unsigned(snake_x_r(29 downto 20)) and R_h_cnt < h_before + unsigned(snake_x_r(29 downto 20)) + square_length) or
                (R_h_cnt >= h_before + unsigned(snake_x_r(39 downto 30)) and R_h_cnt < h_before + unsigned(snake_x_r(39 downto 30)) + square_length and snake_len_r >= 4) or
                (R_h_cnt >= h_before + unsigned(snake_x_r(49 downto 40)) and R_h_cnt < h_before + unsigned(snake_x_r(49 downto 40)) + square_length and snake_len_r >= 5) or
                (R_h_cnt >= h_before + unsigned(snake_x_r(59 downto 50)) and R_h_cnt < h_before + unsigned(snake_x_r(59 downto 50)) + square_length and snake_len_r >= 6) or
                (R_h_cnt >= h_before + unsigned(snake_x_r(69 downto 60)) and R_h_cnt < h_before + unsigned(snake_x_r(69 downto 60)) + square_length and snake_len_r >= 7) or
                (R_h_cnt >= h_before + unsigned(snake_x_r(79 downto 70)) and R_h_cnt < h_before + unsigned(snake_x_r(79 downto 70)) + square_length and snake_len_r >= 8) or
                (R_h_cnt >= h_before + unsigned(snake_x_r(89 downto 80)) and R_h_cnt < h_before + unsigned(snake_x_r(89 downto 80)) + square_length and snake_len_r >= 9) or
                (R_h_cnt >= h_before + unsigned(snake_x_r(99 downto 90)) and R_h_cnt < h_before + unsigned(snake_x_r(99 downto 90)) + square_length and snake_len_r >= 10) or
                (R_h_cnt >= h_before + unsigned(snake_x_r(109 downto 100)) and R_h_cnt < h_before + unsigned(snake_x_r(109 downto 100)) + square_length and snake_len_r >= 11) or
                (R_h_cnt >= h_before + unsigned(snake_x_r(119 downto 110)) and R_h_cnt < h_before + unsigned(snake_x_r(119 downto 110)) + square_length and snake_len_r >= 12) or
                (R_h_cnt >= h_before + unsigned(snake_x_r(129 downto 120)) and R_h_cnt < h_before + unsigned(snake_x_r(129 downto 120)) + square_length and snake_len_r >= 13) or 
                (R_h_cnt >= h_before + unsigned(snake_x_r(139 downto 130)) and R_h_cnt < h_before + unsigned(snake_x_r(139 downto 130)) + square_length and snake_len_r >= 14) or 
                (R_h_cnt >= h_before + unsigned(snake_x_r(149 downto 140)) and R_h_cnt < h_before + unsigned(snake_x_r(149 downto 140)) + square_length and snake_len_r >= 15) or 
                (R_h_cnt >= h_before + unsigned(snake_x_r(159 downto 150)) and R_h_cnt < h_before + unsigned(snake_x_r(159 downto 150)) + square_length and snake_len_r >= 16) or 
                (R_h_cnt >= h_before + unsigned(snake_x_r(169 downto 160)) and R_h_cnt < h_before + unsigned(snake_x_r(169 downto 160)) + square_length and snake_len_r >= 17) or 
                (R_h_cnt >= h_before + unsigned(snake_x_r(179 downto 170)) and R_h_cnt < h_before + unsigned(snake_x_r(179 downto 170)) + square_length and snake_len_r >= 18) or 
                (R_h_cnt >= h_before + unsigned(snake_x_r(189 downto 180)) and R_h_cnt < h_before + unsigned(snake_x_r(189 downto 180)) + square_length and snake_len_r >= 19) or 
                (R_h_cnt >= h_before + unsigned(snake_x_r(199 downto 190)) and R_h_cnt < h_before + unsigned(snake_x_r(199 downto 190)) + square_length and snake_len_r = 20);

                v_issnake := 
                (R_v_cnt >= v_before + unsigned(snake_y_r(9 downto 0)) and R_v_cnt < v_before + unsigned(snake_y_r(9 downto 0)) + square_width) or
                (R_v_cnt >= v_before + unsigned(snake_y_r(19 downto 10)) and R_v_cnt < v_before + unsigned(snake_y_r(19 downto 10)) + square_width) or
                (R_v_cnt >= v_before + unsigned(snake_y_r(29 downto 20)) and R_v_cnt < v_before + unsigned(snake_y_r(29 downto 20)) + square_width) or
                (R_v_cnt >= v_before + unsigned(snake_y_r(39 downto 30)) and R_v_cnt < v_before + unsigned(snake_y_r(39 downto 30)) + square_width and snake_len_r >= 4) or
                (R_v_cnt >= v_before + unsigned(snake_y_r(49 downto 40)) and R_v_cnt < v_before + unsigned(snake_y_r(49 downto 40)) + square_width and snake_len_r >= 5) or
                (R_v_cnt >= v_before + unsigned(snake_y_r(59 downto 50)) and R_v_cnt < v_before + unsigned(snake_y_r(59 downto 50)) + square_width and snake_len_r >= 6) or
                (R_v_cnt >= v_before + unsigned(snake_y_r(69 downto 60)) and R_v_cnt < v_before + unsigned(snake_y_r(69 downto 60)) + square_width and snake_len_r >= 7) or
                (R_v_cnt >= v_before + unsigned(snake_y_r(79 downto 70)) and R_v_cnt < v_before + unsigned(snake_y_r(79 downto 70)) + square_width and snake_len_r >= 8) or
                (R_v_cnt >= v_before + unsigned(snake_y_r(89 downto 80)) and R_v_cnt < v_before + unsigned(snake_y_r(89 downto 80)) + square_width and snake_len_r >= 9) or
                (R_v_cnt >= v_before + unsigned(snake_y_r(99 downto 90)) and R_v_cnt < v_before + unsigned(snake_y_r(99 downto 90)) + square_width and snake_len_r >= 10) or
                (R_v_cnt >= v_before + unsigned(snake_y_r(109 downto 100)) and R_v_cnt < v_before + unsigned(snake_y_r(109 downto 100)) + square_width and snake_len_r >= 11) or
                (R_v_cnt >= v_before + unsigned(snake_y_r(119 downto 110)) and R_v_cnt < v_before + unsigned(snake_y_r(119 downto 110)) + square_width and snake_len_r >= 12) or
                (R_v_cnt >= v_before + unsigned(snake_y_r(129 downto 120)) and R_v_cnt < v_before + unsigned(snake_y_r(129 downto 120)) + square_width and snake_len_r >= 13) or 
                (R_v_cnt >= v_before + unsigned(snake_y_r(139 downto 130)) and R_v_cnt < v_before + unsigned(snake_y_r(139 downto 130)) + square_width and snake_len_r >= 14) or 
                (R_v_cnt >= v_before + unsigned(snake_y_r(149 downto 140)) and R_v_cnt < v_before + unsigned(snake_y_r(149 downto 140)) + square_width and snake_len_r >= 15) or 
                (R_v_cnt >= v_before + unsigned(snake_y_r(159 downto 150)) and R_v_cnt < v_before + unsigned(snake_y_r(159 downto 150)) + square_width and snake_len_r >= 16) or 
                (R_v_cnt >= v_before + unsigned(snake_y_r(169 downto 160)) and R_v_cnt < v_before + unsigned(snake_y_r(169 downto 160)) + square_width and snake_len_r >= 17) or 
                (R_v_cnt >= v_before + unsigned(snake_y_r(179 downto 170)) and R_v_cnt < v_before + unsigned(snake_y_r(179 downto 170)) + square_width and snake_len_r >= 18) or 
                (R_v_cnt >= v_before + unsigned(snake_y_r(189 downto 180)) and R_v_cnt < v_before + unsigned(snake_y_r(189 downto 180)) + square_width and snake_len_r >= 19) or 
                (R_v_cnt >= v_before + unsigned(snake_y_r(199 downto 190)) and R_v_cnt < v_before + unsigned(snake_y_r(199 downto 190)) + square_width and snake_len_r = 20);
            
                issnake := h_issnake and v_issnake;

                issnake_green := 
                ((R_v_cnt >= v_before + unsigned(snake_y_r(9 downto 0)) and R_v_cnt < v_before + unsigned(snake_y_r(9 downto 0)) + square_width) and
                (R_h_cnt >= h_before + unsigned(snake_x_r(9 downto 0)) and R_h_cnt < h_before + unsigned(snake_x_r(9 downto 0)) + square_length)) or
                ((R_v_cnt >= v_before + unsigned(snake_y_r(39 downto 30)) and R_v_cnt < v_before + unsigned(snake_y_r(39 downto 30)) + square_width) and
                (R_h_cnt >= h_before + unsigned(snake_x_r(39 downto 30)) and R_h_cnt < h_before + unsigned(snake_x_r(39 downto 30)) + square_length)) or
                ((R_v_cnt >= v_before + unsigned(snake_y_r(69 downto 60)) and R_v_cnt < v_before + unsigned(snake_y_r(69 downto 60)) + square_width) and
                (R_h_cnt >= h_before + unsigned(snake_x_r(69 downto 60)) and R_h_cnt < h_before + unsigned(snake_x_r(69 downto 60)) + square_length)) or
                ((R_v_cnt >= v_before + unsigned(snake_y_r(99 downto 90)) and R_v_cnt < v_before + unsigned(snake_y_r(99 downto 90)) + square_width) and
                (R_h_cnt >= h_before + unsigned(snake_x_r(99 downto 90)) and R_h_cnt < h_before + unsigned(snake_x_r(99 downto 90)) + square_length)) or
                ((R_v_cnt >= v_before + unsigned(snake_x_r(129 downto 120)) and R_v_cnt < v_before + unsigned(snake_y_r(129 downto 120)) + square_width) and
                (R_h_cnt >= h_before + unsigned(snake_x_r(129 downto 120)) and R_h_cnt < h_before + unsigned(snake_x_r(129 downto 120)) + square_length)) or
                ((R_v_cnt >= v_before + unsigned(snake_y_r(159 downto 150)) and R_v_cnt < v_before + unsigned(snake_y_r(159 downto 150)) + square_width) and
                (R_h_cnt >= h_before + unsigned(snake_x_r(159 downto 150)) and R_h_cnt < h_before + unsigned(snake_x_r(159 downto 150)) + square_length)) or
                ((R_v_cnt >= v_before + unsigned(snake_y_r(189 downto 180)) and R_v_cnt < v_before + unsigned(snake_y_r(189 downto 180)) + square_width) and
                (R_h_cnt >= h_before + unsigned(snake_x_r(189 downto 180)) and R_h_cnt < h_before + unsigned(snake_x_r(189 downto 180)) + square_length));

                issnake_blue :=
                ((R_v_cnt >= v_before + unsigned(snake_y_r(19 downto 10)) and R_v_cnt < v_before + unsigned(snake_y_r(19 downto 10)) + square_width) and
                (R_h_cnt >= h_before + unsigned(snake_x_r(19 downto 10)) and R_h_cnt < h_before + unsigned(snake_x_r(19 downto 10)) + square_length)) or
                ((R_v_cnt >= v_before + unsigned(snake_y_r(49 downto 40)) and R_v_cnt < v_before + unsigned(snake_y_r(49 downto 40)) + square_width) and
                (R_h_cnt >= h_before + unsigned(snake_x_r(49 downto 40)) and R_h_cnt < h_before + unsigned(snake_x_r(49 downto 40)) + square_length)) or
                ((R_v_cnt >= v_before + unsigned(snake_y_r(79 downto 70)) and R_v_cnt < v_before + unsigned(snake_y_r(79 downto 70)) + square_width) and
                (R_h_cnt >= h_before + unsigned(snake_x_r(79 downto 70)) and R_h_cnt < h_before + unsigned(snake_x_r(79 downto 70)) + square_length)) or
                ((R_v_cnt >= v_before + unsigned(snake_y_r(109 downto 100)) and R_v_cnt < v_before + unsigned(snake_y_r(109 downto 100)) + square_width) and
                (R_h_cnt >= h_before + unsigned(snake_x_r(109 downto 100)) and R_h_cnt < h_before + unsigned(snake_x_r(109 downto 100)) + square_length)) or
                ((R_v_cnt >= v_before + unsigned(snake_y_r(139 downto 130)) and R_v_cnt < v_before + unsigned(snake_y_r(139 downto 130)) + square_width) and
                (R_h_cnt >= h_before + unsigned(snake_x_r(139 downto 130)) and R_h_cnt < h_before + unsigned(snake_x_r(139 downto 130)) + square_length)) or
                ((R_v_cnt >= v_before + unsigned(snake_y_r(169 downto 160)) and R_v_cnt < v_before + unsigned(snake_y_r(169 downto 160)) + square_width) and
                (R_h_cnt >= h_before + unsigned(snake_x_r(169 downto 160)) and R_h_cnt < h_before + unsigned(snake_x_r(169 downto 160)) + square_length)) or
                ((R_v_cnt >= v_before + unsigned(snake_y_r(199 downto 190)) and R_v_cnt < v_before + unsigned(snake_y_r(199 downto 190)) + square_width) and
                (R_h_cnt >= h_before + unsigned(snake_x_r(199 downto 190)) and R_h_cnt < h_before + unsigned(snake_x_r(199 downto 190)) + square_length));
             
                issnake_pink := 
                ((R_v_cnt >= v_before + unsigned(snake_y_r(29 downto 20)) and R_v_cnt < v_before + unsigned(snake_y_r(29 downto 20)) + square_width) and
                (R_h_cnt >= h_before + unsigned(snake_x_r(29 downto 20)) and R_h_cnt < h_before + unsigned(snake_x_r(29 downto 20)) + square_length)) or
                ((R_v_cnt >= v_before + unsigned(snake_y_r(59 downto 50)) and R_v_cnt < v_before + unsigned(snake_y_r(59 downto 50)) + square_width) and
                (R_h_cnt >= h_before + unsigned(snake_x_r(59 downto 50)) and R_h_cnt < h_before + unsigned(snake_x_r(59 downto 50)) + square_length)) or
                ((R_v_cnt >= v_before + unsigned(snake_y_r(89 downto 80)) and R_v_cnt < v_before + unsigned(snake_y_r(89 downto 80)) + square_width) and
                (R_h_cnt >= h_before + unsigned(snake_x_r(89 downto 80)) and R_h_cnt < h_before + unsigned(snake_x_r(89 downto 80)) + square_length)) or
                ((R_v_cnt >= v_before + unsigned(snake_y_r(119 downto 110)) and R_v_cnt < v_before + unsigned(snake_y_r(119 downto 110)) + square_width) and
                (R_h_cnt >= h_before + unsigned(snake_x_r(119 downto 110)) and R_h_cnt < h_before + unsigned(snake_x_r(119 downto 110)) + square_length)) or
                ((R_v_cnt >= v_before + unsigned(snake_y_r(149 downto 140)) and R_v_cnt < v_before + unsigned(snake_y_r(149 downto 140)) + square_width) and
                (R_h_cnt >= h_before + unsigned(snake_x_r(149 downto 140)) and R_h_cnt < h_before + unsigned(snake_x_r(149 downto 140)) + square_length)) or
                ((R_v_cnt >= v_before + unsigned(snake_y_r(179 downto 170)) and R_v_cnt < v_before + unsigned(snake_y_r(179 downto 170)) + square_width) and
                (R_h_cnt >= h_before + unsigned(snake_x_r(179 downto 170)) and R_h_cnt < h_before + unsigned(snake_x_r(179 downto 170)) + square_length));

                h_isfood := (R_h_cnt >= h_before + food_x) and (R_h_cnt < h_before + food_x + square_length);
                v_isfood := (R_v_cnt >= v_before + food_y) and (R_v_cnt < v_before + food_y + square_width);
                isfood := h_isfood and v_isfood;

                case general_state is
                    when start =>
                        red_r   <= (others => '0');
                        green_r <= (others => '0');
                        blue_r  <= (others => '0');

                    when diff_menu =>
                        case difficulty_state is
                            when easy =>
                                if (R_v_cnt >= v_before + 220 and R_v_cnt < v_before + 260) then
                                    if (R_h_cnt >= h_before + 220 and R_h_cnt < h_before + 260) then
                                        red_r   <= (others => '0');
                                        green_r <= (others => '0');
                                        blue_r  <= (others => '0');
                                    elsif (R_h_cnt >= h_before + 300 and R_h_cnt < h_before + 340) then
                                        red_r   <= (others => '0');
                                        green_r <= (others => '0');
                                        blue_r  <= (others => '1');
                                    elsif (R_h_cnt >= h_before + 380 and R_h_cnt < h_before + 420) then
                                        red_r   <= (others => '0');
                                        green_r <= (others => '0');
                                        blue_r  <= (others => '1');
                                    else
                                        red_r   <= (others => '1');
                                        green_r <= (others => '1');
                                        blue_r  <= (others => '1');
                                    end if;
                                else
                                    red_r   <= (others => '1');
                                    green_r <= (others => '1');
                                    blue_r  <= (others => '1');
                                end if;
                            when mid =>
                                if (R_v_cnt >= v_before + 220 and R_v_cnt < v_before + 260)  then 
                                    if (R_h_cnt >= h_before + 300 and R_h_cnt < h_before + 340) then
                                        red_r   <= (others => '0');
                                        green_r <= (others => '0');
                                        blue_r  <= (others => '0');
                                    elsif (R_h_cnt >= h_before + 220 and R_h_cnt < h_before + 260) then
                                        red_r   <= (others => '0');
                                        green_r <= (others => '0');
                                        blue_r  <= (others => '1');
                                    elsif (R_h_cnt >= h_before + 380 and R_h_cnt < h_before + 420) then
                                        red_r   <= (others => '0');
                                        green_r <= (others => '0');
                                        blue_r  <= (others => '1');
                                    else 
                                        red_r   <= (others => '1');
                                        green_r <= (others => '1');
                                        blue_r  <= (others => '1');
                                    end if;
                                else
                                    red_r   <= (others => '1');
                                    green_r <= (others => '1');
                                    blue_r  <= (others => '1');
                                end if;
                            when hard =>
                                if (R_v_cnt >= v_before + 220 and R_v_cnt < v_before + 260)  then 
                                    if (R_h_cnt >= h_before + 380 and R_h_cnt < h_before + 420) then
                                        red_r   <= (others => '0');
                                        green_r <= (others => '0');
                                        blue_r  <= (others => '0');
                                    elsif (R_h_cnt >= h_before + 300 and R_h_cnt < h_before + 340) then
                                        red_r   <= (others => '0');
                                        green_r <= (others => '0');
                                        blue_r  <= (others => '1');
                                    elsif (R_h_cnt >= h_before + 220 and R_h_cnt < h_before + 260) then
                                        red_r   <= (others => '0');
                                        green_r <= (others => '0');
                                        blue_r  <= (others => '1');
                                    else 
                                        red_r   <= (others => '1');
                                        green_r <= (others => '1');
                                        blue_r  <= (others => '1');
                                    end if;
                                else
                                    red_r   <= (others => '1');
                                    green_r <= (others => '1');
                                    blue_r  <= (others => '1');
                                end if;
                            end case;
                    when game_start =>
                        if    
                        (
                            (R_h_cnt >= h_before + unsigned(snake_x_r(9 downto 0)) and R_h_cnt < h_before + unsigned(snake_x_r(9 downto 0)) + square_length
                            and R_v_cnt >= v_before + unsigned(snake_y_r(9 downto 0)) and R_v_cnt < v_before + unsigned(snake_y_r(9 downto 0)) + square_width)
                            or (R_h_cnt >= h_before + unsigned(snake_x_r(19 downto 10)) and R_h_cnt < h_before + unsigned(snake_x_r(19 downto 10)) + square_length
                            and R_v_cnt >= v_before + unsigned(snake_y_r(19 downto 10)) and R_v_cnt < v_before + unsigned(snake_y_r(19 downto 10)) + square_width)
                            or (R_h_cnt >= h_before + unsigned(snake_x_r(29 downto 20)) and R_h_cnt < h_before + unsigned(snake_x_r(29 downto 20)) + square_length
                            and R_v_cnt >= v_before + unsigned(snake_y_r(29 downto 20)) and R_v_cnt < v_before + unsigned(snake_y_r(29 downto 20)) + square_width)
                        )  then
                            red_r   <= (others => '0');
                            green_r <= (others => '1');
                            blue_r  <= (others => '0');
                        else
                            red_r   <= (others => '1');
                            green_r <= (others => '1');
                            blue_r  <= (others => '1');
                        end if ;
                    when gaming =>
                        if (isfood = TRUE) then 
                            red_r   <= (others => '1');
                            green_r <= (others => '0');
                            blue_r  <= (others => '0');
                        elsif (issnake_green = TRUE and issnake = TRUE) then
                            red_r   <= (others => '0');
                            green_r <= (others => '1');
                            blue_r  <= (others => '0');
                        elsif (issnake_blue = TRUE and issnake = TRUE) then
                            red_r   <= (others => '0');
                            green_r <= (others => '0');
                            blue_r  <= (others => '1');
                        elsif (issnake_pink = TRUE and issnake = TRUE) then
                            red_r   <= (others => '1');
                            green_r <= (others => '0');
                            blue_r  <= (others => '1');
                        else
                            red_r   <= (others => '1');
                            green_r <= (others => '1');
                            blue_r  <= (others => '1');
                        end if;   
                    when others =>
                        red_r   <= (others => '0');
                        green_r <= (others => '0');
                        blue_r  <= (others => '0');
                end case;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------
    -- 端口输出
    ------------------------------------------------------------------
    O_red         <= red_r;
    O_green       <= green_r;
    O_blue        <= blue_r;
    snake_x       <= snake_x_r;
    snake_y       <= snake_y_r;
    snake_length  <= std_logic_vector(snake_len_r);
    flag_isdead   <= isdead_r;

end Behavioral;
