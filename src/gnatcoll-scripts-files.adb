------------------------------------------------------------------------------
--                             G N A T C O L L                              --
--                                                                          --
--                     Copyright (C) 2003-2014, AdaCore                     --
--                                                                          --
-- This library is free software;  you can redistribute it and/or modify it --
-- under terms of the  GNU General Public License  as published by the Free --
-- Software  Foundation;  either version 3,  or (at your  option) any later --
-- version. This library is distributed in the hope that it will be useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE.                            --
--                                                                          --
-- As a special exception under Section 7 of GPL version 3, you are granted --
-- additional permissions described in the GCC Runtime Library Exception,   --
-- version 3.1, as published by the Free Software Foundation.               --
--                                                                          --
-- You should have received a copy of the GNU General Public License and    --
-- a copy of the GCC Runtime Library Exception along with this program;     --
-- see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see    --
-- <http://www.gnu.org/licenses/>.                                          --
--                                                                          --
------------------------------------------------------------------------------

with GNATCOLL.Projects;       use GNATCOLL.Projects;
with GNATCOLL.VFS;            use GNATCOLL.VFS;
with GNATCOLL.VFS_Utils;      use GNATCOLL.VFS_Utils;
with GNATCOLL.Scripts.Projects;

package body GNATCOLL.Scripts.Files is

   type File_Properties_Record is new Instance_Property_Record with record
      File : Virtual_File;
   end record;

   procedure File_Command_Handler
     (Data : in out Callback_Data'Class; Command : String);
   --  Handler for the "File" commands

   File_Class_Name          : constant String := "File";

   Default_Cst    : aliased constant String := "default_to_root";
   Name_Cst       : aliased constant String := "name";
   Local_Cst      : aliased constant String := "local";
   Server_Cst     : aliased constant String := "remote_server";

   File_Cmd_Parameters   : constant Cst_Argument_List :=
                                (1 => Name_Cst'Access,
                                 2 => Local_Cst'Access);
   File_Name_Parameters  : constant Cst_Argument_List :=
                                (1 => Server_Cst'Access);
   File_Project_Parameters  : constant Cst_Argument_List :=
                                (1 => Default_Cst'Access);
   -----------------
   -- Create_File --
   -----------------

   function Create_File
     (Script : access Scripting_Language_Record'Class;
      File   : GNATCOLL.VFS.Virtual_File) return Class_Instance
   is
      Instance : constant Class_Instance := New_Instance
        (Script, New_Class (Get_Repository (Script), File_Class_Name));
   begin
      Set_Data (Instance, File);
      return Instance;
   end Create_File;

   --------------
   -- Get_Data --
   --------------

   function Get_Data
     (Instance : Class_Instance) return GNATCOLL.VFS.Virtual_File
   is
      Data : Instance_Property;
   begin
      if Instance /= No_Class_Instance then
         Data := Get_Data (Instance, File_Class_Name);
      end if;

      if Data = null then
         return GNATCOLL.VFS.No_File;
      else
         return File_Properties_Record (Data.all).File;
      end if;
   end Get_Data;

   --------------------
   -- Get_File_Class --
   --------------------

   function Get_File_Class
     (Data : Callback_Data'Class)
      return Class_Type is
   begin
      return New_Class (Data.Get_Repository, File_Class_Name);
   end Get_File_Class;

   --------------------------
   -- File_Command_Handler --
   --------------------------

   procedure File_Command_Handler
     (Data : in out Callback_Data'Class; Command : String)
   is
      Repo   : constant Scripts_Repository := Get_Repository (Data);
      Info    : Virtual_File;
      Project : Project_Type;
   begin
      if Command = Constructor_Method then
         Name_Parameters (Data, File_Cmd_Parameters);

         declare
            Instance : constant Class_Instance :=
                         Nth_Arg (Data, 1, Get_File_Class (Data));
            Name     : constant Filesystem_String := Nth_Arg (Data, 2);
         begin
            if Is_Absolute_Path (Name) then
               Set_Data (Instance, Create (Name));
               return;
            end if;

            --  Base name case. Find full name using the following rules:
            --  1) If third argument is set to true, create from current dir
            --  else
            --  2) If Base Name can be found in project, use it
            --  else
            --  3) Create from current dir

            --  If we really want to create from current directory

            if Number_Of_Arguments (Data) > 2 then
               declare
                  From_Current : constant Boolean := Nth_Arg (Data, 3);
               begin
                  if From_Current then
                     Set_Data
                       (Instance,
                        Create_From_Dir (Get_Current_Dir, Name));
                     return;
                  end if;
               end;
            end if;

            if Repo.Project_Tree /= null then
               declare
                  File : constant Virtual_File :=
                    Repo.Project_Tree.Create
                      (Base_Name (Create_From_Base (Name)));
               begin
                  if File /= No_File then
                     Set_Data (Instance, File);
                     return;
                  end if;
               end;
            end if;

            Set_Data (Instance, Create_From_Base (Name));
         end;

      elsif Command = "name" then
         Name_Parameters (Data, File_Name_Parameters);
         Info := Nth_Arg (Data, 1);
         --  Ignore server argument here
         Set_Return_Value (Data, Full_Name (Info));

      elsif Command = "directory" then
         Info := Nth_Arg (Data, 1);
         Set_Return_Value (Data, Dir_Name (Info));

      elsif Command = "other_file" then
         if Repo.Project_Tree = null then
            Set_Error_Msg (Data, "Project not set");
            return;
         end if;

         Info  := Nth_Arg (Data, 1);
         Set_Return_Value
           (Data,
            Create_File (Get_Script (Data),
                         Repo.Project_Tree.Other_File (Info)));

      elsif Command = "project" then
         if Repo.Project_Tree = null then
            Set_Error_Msg (Data, "Project not set");
            return;
         end if;

         Name_Parameters (Data, File_Project_Parameters);
         Info := Nth_Arg (Data, 1);

         --  Return the first possible project, we have nothing else to base
         --  our guess on.
         declare
            F_Info : constant File_Info'Class :=
              File_Info'Class
                (Repo.Project_Tree.Info_Set (Info).First_Element);
         begin
            Project := F_Info.Project;
         end;

         if Project = No_Project and then Nth_Arg (Data, 2, True) then
            Project := Repo.Project_Tree.Root_Project;
         end if;

         Set_Return_Value
           (Data,
            GNATCOLL.Scripts.Projects.Create_Project
              (Get_Script (Data), Project));

      end if;
   end File_Command_Handler;

   --------------------
   -- Get_File_Class --
   --------------------

   function Get_File_Class
     (Repo : access Scripts_Repository_Record'Class)
      return Class_Type is
   begin
      return New_Class (Repo, File_Class_Name);
   end Get_File_Class;

   -------------
   -- Nth_Arg --
   -------------

   function Nth_Arg
     (Data : Callback_Data'Class; N : Positive)
      return GNATCOLL.VFS.Virtual_File
   is
      Class : constant Class_Type := Get_File_Class (Data);
      Inst  : constant Class_Instance := Nth_Arg (Data, N, Class);
   begin
      return Get_Data (Inst);
   end Nth_Arg;

   -----------------------
   -- Register_Commands --
   -----------------------

   procedure Register_Commands
     (Repo : access Scripts_Repository_Record'Class;
      Tree : GNATCOLL.Projects.Project_Tree_Access)
   is
   begin
      Repo.Project_Tree := Tree;

      Register_Command
        (Repo, Constructor_Method,
         Minimum_Args => 1,
         Maximum_Args => 2,
         Class        => Get_File_Class (Repo),
         Handler      => File_Command_Handler'Access);
      Register_Command
        (Repo, "name",
         Minimum_Args => 0,
         Maximum_Args => 1,
         Class        => Get_File_Class (Repo),
         Handler      => File_Command_Handler'Access);
      Register_Command
        (Repo, "directory",
         Class        => Get_File_Class (Repo),
         Handler      => File_Command_Handler'Access);
      Register_Command
        (Repo, "other_file",
         Class        => Get_File_Class (Repo),
         Handler      => File_Command_Handler'Access);
      Register_Command
        (Repo, "project",
         Minimum_Args => 0,
         Maximum_Args => 1,
         Class        => Get_File_Class (Repo),
         Handler      => File_Command_Handler'Access);
   end Register_Commands;

   --------------
   -- Set_Data --
   --------------

   procedure Set_Data (Instance : Class_Instance; File : Virtual_File) is
   begin
      if not Is_Subclass (Instance, File_Class_Name) then
         raise Invalid_Data;
      end if;

      Set_Data
        (Instance, File_Class_Name,
         File_Properties_Record'(File => File));
   end Set_Data;

   -----------------
   -- Set_Nth_Arg --
   -----------------

   procedure Set_Nth_Arg
     (Data : in out Callback_Data'Class;
      N    : Positive;
      File : GNATCOLL.VFS.Virtual_File)
   is
      Inst  : constant Class_Instance := Create_File (Get_Script (Data), File);
   begin
      Set_Nth_Arg (Data, N, Inst);
   end Set_Nth_Arg;

end GNATCOLL.Scripts.Files;