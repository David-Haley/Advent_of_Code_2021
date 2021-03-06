with Ada.Text_IO; use Ada.Text_IO;
with Ada.Command_Line; use Ada.Command_Line;
with Ada.Text_IO.Unbounded_IO; use Ada.Text_IO.Unbounded_IO;
with Ada.Strings; use Ada.Strings;
with Ada.Strings.Maps; use Ada.Strings.Maps;
with Ada.Strings.Maps.Constants; use Ada.Strings.Maps.Constants;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Containers; use Ada.Containers;
with Ada.Containers.Vectors;
with Ada.Containers.Ordered_Sets;
with Ada.Containers.Synchronized_Queue_Interfaces;
with Ada.Containers.Unbounded_Priority_Queues;
with DJH.Execution_Time;

procedure December_19 is

   type Axies is (X_Axis, Y_Axis, Z_Axis);

   subtype Offsets is Integer;

   subtype Rotations is Natural range 0 .. 23;
   R0 : constant Rotations := Rotations'First;

   subtype Rotation_Elements is Integer range -1 .. 1;
   type Coordinates is array (Axies) of Offsets;

   subtype Beacon_Indices is Positive;
   package Beacon_Lists is new
     Ada.Containers.Vectors (Beacon_Indices, Coordinates);
   use Beacon_Lists;

   type Beacon_Arrays is array (Rotations) of Beacon_Lists.Vector;

   subtype Scanner_Indices is Natural;
   type Scanners is record
      Beacon_Array : Beacon_Arrays := (others => Beacon_Lists.Empty_Vector);
      Position_Known : Boolean := False;
      Orientation : Rotations := Rotations'First;
      Position : Coordinates := (0, 0, 0);
   end record; -- Scanners

   package Scanner_Lists is new
     Ada.Containers.Vectors (Scanner_Indices, Scanners);
   use Scanner_Lists;

   function "<" (Left, Right : Coordinates) return Boolean is

   begin -- "<"
      return Left (X_Axis) < Right (X_Axis)
        or
          (Left (X_Axis) = Right (X_Axis) and (Left (Y_Axis) < Right (Y_Axis)
                                               or
                                                 (Left (Y_Axis) = Right (Y_Axis) and
                                                      Left (Z_Axis) < Right (Z_Axis))));
   end "<";

   package Beacon_Sets is new Ada.Containers.Ordered_Sets (Coordinates);
   use Beacon_Sets;

   procedure Build_Rotations (Scanner : in out Scanners) is

      function Rotate (Coordinate : in Coordinates;
                       Rotation : in Rotations) return Coordinates is

         type Rotation_Matrix is Array (Axies, Axies) of Rotation_Elements;

         Rotation_Table : constant array (Rotations) of Rotation_Matrix :=
           (
            00 => (( 1,  0,  0),
                   ( 0,  1,  0),
                   ( 0,  0,  1)), -- no rotation
            01 => (( 1,  0,  0),
                   ( 0,  0, -1),
                   ( 0,  1,  0)),
            02 => (( 1,  0,  0),
                   ( 0, -1,  0),
                   ( 0,  0, -1)),
            03 => (( 1,  0,  0),
                   ( 0,  0,  1),
                   ( 0, -1,  0)),
            04 => (( 0, -1,  0),
                   ( 1,  0,  0),
                   ( 0,  0,  1)),
            05 => (( 0,  0,  1),
                   ( 1,  0,  0),
                   ( 0,  1,  0)),
            06 => (( 0,  1,  0),
                   ( 1,  0,  0),
                   ( 0,  0, -1)),
            07 => (( 0,  0, -1),
                   ( 1,  0,  0),
                   ( 0, -1,  0)),
            08 => ((-1,  0,  0),
                   ( 0, -1,  0),
                   ( 0,  0,  1)),
            09 => ((-1,  0,  0),
                   ( 0,  0, -1),
                   ( 0, -1,  0)),
            10 => ((-1,  0,  0),
                   ( 0,  1,  0),
                   ( 0,  0, -1)),
            11 => ((-1,  0,  0),
                   ( 0,  0,  1),
                   ( 0,  1,  0)),
            12 => (( 0,  1,  0),
                   (-1,  0,  0),
                   ( 0,  0,  1)),
            13 => (( 0,  0,  1),
                   (-1,  0,  0),
                   ( 0, -1,  0)),
            14 => (( 0, -1,  0),
                   (-1,  0,  0),
                   ( 0,  0, -1)),
            15 => (( 0,  0, -1),
                   (-1,  0,  0),
                   ( 0,  1,  0)),
            16 => (( 0,  0, -1),
                   ( 0,  1,  0),
                   ( 1,  0,  0)),
            17 => (( 0,  1,  0),
                   ( 0,  0,  1),
                   ( 1,  0,  0)),
            18 => (( 0,  0,  1),
                   ( 0, -1,  0),
                   ( 1,  0,  0)),
            19 => (( 0, -1,  0),
                   ( 0,  0, -1),
                   ( 1,  0,  0)),
            20 => (( 0,  0, -1),
                   ( 0, -1,  0),
                   (-1,  0,  0)),
            21 => (( 0, -1,  0),
                   ( 0,  0,  1),
                   (-1,  0,  0)),
            22 => (( 0,  0,  1),
                   ( 0,  1,  0),
                   (-1,  0,  0)),
            23 => (( 0,  1,  0),
                   ( 0,  0, -1),
                   (-1,  0,  0)));

         Result : Coordinates;

      begin -- Rotate
         for Axis_In in Axies loop
            for Axis_Out in Axies loop
               if Rotation_Table (Rotation) (Axis_In, Axis_Out) = 1 then
                  Result (Axis_Out) := Coordinate (Axis_In);
               elsif Rotation_Table (Rotation) (Axis_In, Axis_Out) = -1 then
                  Result (Axis_Out) := - Coordinate (Axis_In);
               end if; -- Rotation_Table (Rotation) (Axis_In, Axis_Out)
            end loop; --  Axis_Out in Axies
         end loop; -- Axis_In in Axies
         return Result;
      end Rotate;

   begin -- Build_Rotations
      for R in Rotations range R0 + 1 .. Rotations'Last  loop
         Scanner.Beacon_Array (R) := Beacon_Lists.Empty_Vector;
         for B in Iterate (Scanner.Beacon_Array (R0)) loop
            Append (Scanner.Beacon_Array (R),
                    Rotate (Scanner.Beacon_Array (R0) (B), R));
         end loop; -- B in Iterate (Scanner.Beacon_Array (R0))
      end loop; -- R in Rotations range R0 + 1 .. Rotations'Last
   end Build_Rotations;

   procedure Get_Input (Scanner_List : out Scanner_Lists.Vector) is

      -- december_19 [Input_File_Name]

      Input_File : File_Type;
      Text : Unbounded_String;
      Scanner_String : constant String := "--- scanner";
      Integer_Set : constant Character_Set := To_Set ("-0123456789");
      Start_At, First : Positive;
      Last : Natural;
      Scanner_Index : Scanner_Indices := 0;
      Scanner : Scanners;
      Beacon : Coordinates;

   begin -- Get_Input
      if Argument_Count = 0 then
         Open (Input_File, In_File, "december_19.txt");
      else
         Open (Input_File, In_File, Argument(1));
      end if; -- Argument_Count = 0
      while not End_Of_File (Input_File) loop
         Get_Line (Input_File, Text);
         if Length (Text) = 0 then
            Build_Rotations (Scanner);
            Append (Scanner_List, Scanner);
            Scanner.Beacon_Array (R0) := Beacon_Lists.Empty_Vector;
         elsif Index (Text, Scanner_String) /= 0 then
            Start_At := Scanner_String'Length + Index (Text, Scanner_String);
            Find_Token (Text, Decimal_Digit_Set, Start_At, Inside, First, Last);
            Scanner_Index := Scanner_Indices'Value (Slice (Text, First, Last));
            Scanner.Position_Known := Scanner_Index = Scanner_Indices'First;
         else
            Start_At := 1;
            for A in Axies loop
               Find_Token (Text, Integer_Set, Start_At, Inside, First, Last);
               Beacon (A) := Offsets'Value (Slice (Text, First, Last));
               Start_At := Last + 1;
            end loop; -- A in Axies
            Append (Scanner.Beacon_Array (R0), Beacon);
         end if; -- Length (Text) = 0
      end loop; -- End_Of_File (Input_File)
      -- Save last Scanner if there was no blank line before EOF
      if Length (Scanner.Beacon_Array (R0)) > 0 then
         Build_Rotations (Scanner);
         Append (Scanner_List, Scanner);
      end if; -- Length (Scanner.Beacon_Array (R0)) > 0
      Close (Input_File);
   end Get_Input;

   function "+" (Left, Right : Coordinates) return Coordinates is

   begin -- "+"
      return (Left (X_Axis) + Right (X_Axis),
              Left (Y_Axis) + Right (Y_Axis),
              Left (Z_Axis) + Right (Z_Axis));
   end "+";

   function "-" (Left, Right : Coordinates) return Coordinates is

   begin -- "-"
      return (Left (X_Axis) - Right (X_Axis),
              Left (Y_Axis) - Right (Y_Axis),
              Left (Z_Axis) - Right (Z_Axis));
   end "-";

   procedure Find_Matches (Scanner_List : in out Scanner_Lists.Vector) is

      type Queue_Elements is record
         Scanner_Index : Scanner_Indices;
         Position : Coordinates;
      end record; -- Queue_Elements

      function Get_Priority (Queue_Element : Queue_Elements) return Natural is

      begin -- Get_Priority
         return abs (Queue_Element.Position (X_Axis)) +
         abs (Queue_Element.Position (Y_Axis)) +
         abs (Queue_Element.Position (Z_Axis));
      end Get_Priority;

      function Before (Left, Right : Natural) return Boolean is

      begin -- Before
         return Left < Right;
      end Before;

      package QI is new
        Ada.Containers.Synchronized_Queue_Interfaces (Queue_Elements);

      package Queues is new
        Ada.Containers.Unbounded_Priority_Queues (QI,
                                                  Queue_Priority => Natural);
      use Queues;

      procedure Match_Pair (Known : in Scanners;
                            Unknown : in out Scanners) is

         function Count_Matches (Known, Unknown : in Beacon_Lists.Vector)
                                 return natural is

            package Match_Sets is new
              Ada.Containers.Ordered_Sets (Beacon_Indices);
            use Match_Sets;

            Known_Set, Unknown_Set : Match_Sets.Set;
            Count : Natural := 0;

         begin -- Count_Matches
            for Bk in iterate (Known) loop
               for Bu in Iterate (Unknown) loop
                  if not Contains (Known_Set, To_Index (Bk)) and
                    not Contains (Unknown_Set, To_Index (Bu)) and
                    -- Theoretically the = operator should be defined for
                    -- Coordinates because = and /= are intrinsic to most data
                    -- types specifically arrays and records, compilerbug ?;
                    Known (Bk) (X_Axis) = Unknown (Bu) (X_Axis) and
                    Known (Bk) (Y_Axis) = Unknown (Bu) (Y_Axis) and
                    Known (Bk) (Z_Axis) = Unknown (Bu) (Z_Axis) then
                     Count := Count + 1;
                     Include (Known_Set, To_Index (Bk));
                     Include (Unknown_Set, To_Index (Bu));
                  end if; -- not Contains (Known_Set, To_Index (Bk)) and ...
               end loop; -- Bu in Iterate (Unknown)
            end loop; -- Bk in iterate (Known)
            return Count;
         end Count_Matches;

         Required_Matches : constant Natural := 12;
         Difference : Coordinates;
         Rk : Rotations := Known.Orientation;
         Reference, Corrected : Beacon_Lists.Vector;
         Match_Found : Boolean := False;
         Ru : Rotations := Rotations'First;
         Bk, Bu : Beacon_Lists.Cursor;

      begin -- Match_Pair
         Assign (Reference, Known.Beacon_Array (Rk));
         loop -- Ru
            Bk := First (Reference);
            while Bk /= Beacon_Lists.No_Element and not Match_Found loop
               Bu := First (Unknown.Beacon_Array (Ru));
               while Bu /= Beacon_Lists.No_Element and not Match_Found loop
                  Difference := Reference (Bk) - Unknown.Beacon_Array (Ru) (Bu);
                  Corrected := Beacon_Lists.Empty_Vector;
                  for B in Iterate (Unknown.Beacon_Array (Ru)) loop
                     Append (Corrected,
                             Unknown.Beacon_Array (Ru) (B) + Difference);
                  end loop; -- B in Iterate (Unknown.Beacon_Array (Ru))
                  Match_Found := Count_Matches (Reference, Corrected) >=
                    Required_Matches;
                  if Match_Found then
                     Unknown.Position_Known := True;
                     Unknown.Orientation := Ru;
                     Unknown.Position := Known.Position + Difference;
                  end if; -- Count_Matches (Reference, Corrected) >= ...
                  Next (Bu);
               end loop; -- Bu /= Beacon_Lists.No_Element and not Match_Found
               Next (Bk);
            end loop; -- Bk /= Beacon_Lists.No_Element and not Match_Found
            exit when Ru >= Rotations'Last or Match_Found;
            Ru := Ru + 1;
         end loop; -- Ru
      end Match_Pair;

      Queue_In, Queue_Out : Queue_Elements;
      Known_Queue : Queues.Queue;

   begin -- Find_Matches
      Queue_In.Scanner_Index := First_Index (Scanner_List);
      Queue_In.Position :=
        Scanner_List (Queue_In.Scanner_Index).Position;
      Known_Queue.Enqueue (Queue_In);
      while Known_Queue.Current_Use > 0 loop
         Known_Queue.Dequeue (Queue_Out);
         for Su in iterate (Scanner_List) loop
            if not Scanner_List (Su).Position_Known then
               Match_Pair (Scanner_List (Queue_Out.Scanner_Index),
                           Scanner_list (Su));
               if Scanner_List (Su).Position_Known then
                  Queue_In.Scanner_Index := To_Index (Su);
                  Queue_In.Position :=
                    Scanner_List (Queue_In.Scanner_Index).Position;
                  Known_Queue.Enqueue (Queue_In);
               end if; -- Scanner_List (Sk).Known_Position and ...
            end if; -- not Scanner_List (Su).Position_Known
         end loop; -- Su in iterate (Scanner_List)
      end loop; -- Known_Queue.Current_Use
   end Find_Matches;

   function All_Matched (Scanner_List : in Scanner_Lists.Vector)
                         return Boolean is

      Result : Boolean := True;

   begin -- All_Matched
      for S in Iterate (Scanner_List) loop
         Result := Result and Scanner_List (S).Position_Known;
      end loop; -- S in Iterate (Scanner_List)
      return Result;
   end All_Matched;

   procedure Build_Beacon_Set (Scanner_List : in Scanner_Lists.Vector;
                               Beacon_Set : out Beacon_Sets.Set) is

      R : Rotations;

   begin -- Build_Beacon_Set
      for S in Iterate (Scanner_List) loop
         R := Scanner_List (S).Orientation;
         for B in Iterate (Scanner_List (S).Beacon_Array (R)) loop
            Include (Beacon_Set, Scanner_List (S).Beacon_Array (R) (B)
                     + Scanner_List (S).Position);
         end loop; -- B in Iterate (Scanner_List (S).Beacon_Array (R))
      end loop; -- S in Iterate (Scanner_List)
   end Build_Beacon_Set;

   function Maximum_Distance (Scanner_List : in Scanner_Lists.Vector)
                              return Natural is

      function Distance (Left, Right : in Coordinates) return Natural is

         -- Manhattan distance

      begin -- Distance
         return abs (Left (X_Axis) - Right (X_Axis)) +
         abs (Left (Y_Axis) - Right (Y_Axis)) +
         abs (Left (Z_Axis) - Right (Z_Axis));
      end Distance;

      Result : Natural := Natural'First;

   begin -- Maximum_Distance
      for S1 in Scanner_Indices range Scanner_Indices'First ..
        Last_Index (Scanner_List) - 1 loop
         for S2 in Scanner_Indices range S1 + 1 ..
           Last_Index (Scanner_List) loop
            if Result < Distance (Scanner_List (S1).Position,
                                  Scanner_List (S2).Position) then
               Result := Distance (Scanner_List (S1).Position,
                                   Scanner_List (S2).Position);
            end if; -- Result < Distance (Scanner_List (S1).Position, ...
         end loop; -- S2 in Scanner_Indices range S1 + 1 ...
      end loop; -- S1 in Scanner_Indices range Scanner_Indices'First ..
      return Result;
   end Maximum_Distance;

   Scanner_List : Scanner_Lists.Vector;
   Beacon_Set : Beacon_Sets. Set;

begin -- December_19
   Get_Input (Scanner_List);
   Find_Matches (Scanner_List);
   if All_Matched (Scanner_List) then
      Build_Beacon_Set (Scanner_List, Beacon_Set);
      Put_Line ("Part One Answer:" & Length (Beacon_Set)'Img);
      DJH.Execution_Time.Put_CPU_Time;
      Put_Line ("Part Two Answer:" & Maximum_Distance (Scanner_List)'Img);
      DJH.Execution_Time.Put_CPU_Time;
   else
      Put ("Unmatched scanners");
      for S in Iterate (Scanner_List) loop
         Put (To_Index (S)'Img);
      end loop; -- S in Iterate (Scanner_Lists)
      New_line;
   end if;
end December_19;
