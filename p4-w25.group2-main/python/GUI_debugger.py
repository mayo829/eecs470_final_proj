import tkinter as tk
from tkinter import ttk
from tkinter import filedialog

class VCDParser:
    def __init__(self):
        self.variables = {}
        self.times = []
        self.values = {}
        
    def get_actual_var_id(self, potential_var_id: str) -> str:
        # First, check the full potential_var_id across all modules
        for module in self.variables:
            if potential_var_id in self.variables[module]:
                return module, potential_var_id

        # If no match is found, progressively remove the first character and check again
        current_var_id = potential_var_id
        while current_var_id:
            # Check all modules for the current shortened version of potential_var_id
            for module in self.variables:
                if current_var_id in self.variables[module]:
                    return module, current_var_id
            
            # Remove the first character and try again
            current_var_id = current_var_id[1:]

        # If no match is found, return None (or any appropriate value)
        return None

    def parse_vcd(self, file_path):
        max_id_len = 0
        start_parsing_init_state = False
        start_parsing_time = False
        getTime = False
        current_module = None  # To track the current module being parsed
        time = 0
        
        with open(file_path, 'r') as file:
            lines = file.readlines()

        current_time = None
        for line in lines:
            line = line.strip()
            
            if line.startswith("$timescale"):
                getTime = True
            elif getTime:
                time = line.strip()
                getTime = False
            # Handle module scope - define the current module
            elif line.startswith("$scope module"):
                # Extract the module name (after the word 'module')
                parts = line.split()
                current_module = parts[2]  # Module name (e.g., verisimpleV)

                # Initialize the module's dictionary if not already present
                if current_module not in self.variables:
                    self.variables[current_module] = {}
            # Parsing the header section (variable definitions)
            elif line.startswith("$var"):
                if current_module is not None:
                    parts = line.split()
                    var_type = parts[1]  # Variable type (e.g., reg)
                    var_size = parts[2]  # Variable size (e.g., 1 or 3)
                    var_id = parts[3]    # Variable ID (unique identifier)
                    var_name = parts[4]  # Variable name (e.g., clock)
                    
                    id_len = len(var_id)
                    if id_len > max_id_len:
                        max_id_len = id_len

                    # Group variables by module
                    self.variables[current_module][var_id] = {
                        'type': var_type,
                        'size': var_size,
                        'name': var_name,
                        'value': None
                    }

            # Start parsing the $dumpvars section (module data begins here)
            elif line == "$dumpvars":
                start_parsing_init_state = True
                current_time = 0
                self.values[current_time] = {}
                self.times.append(current_time)
            # Parsing the value updates (b = binary value, x = unknown)
            elif start_parsing_init_state:
                if line.startswith("$end"):
                    start_parsing_init_state = False
                    start_parsing_time = True
                else:
                    pot_var_id = line[-max_id_len:]
                    var_id = self.get_actual_var_id(pot_var_id)[1]
                    val_no_space = line.replace(" ", "")  # Remove all spaces
                    val = val_no_space[:-len(var_id)]
                    self.values[current_time][var_id] = val
            
            elif start_parsing_time:
                # Parsing the time steps
                if line.startswith("#"):
                    current_time = int(line[1:])
                    self.times.append(current_time)
                    self.values[current_time] = {}
                else:
                    pot_var_id = line[-max_id_len:]
                    var_id = self.get_actual_var_id(pot_var_id)[1]
                    val_no_space = line.replace(" ", "")  # Remove all spaces
                    val = val_no_space[:-len(var_id)]
                    self.values[current_time][var_id] = val



    def get_state_at_time(self, time):
        """Return the state of variables at a specific time step"""
        return self.values.get(time, {})


class TabExplorerApp:
    def __init__(self, root):
        self.root = root
        self.root.title("VCD File Explorer")
        self.root.geometry("1920x1080")

        # Timer state
        self.current_time_index = 0
        self.current_time = 0

        # Create a frame for the module selection
        self.module_frame = ttk.Frame(self.root)
        self.module_frame.pack(side=tk.LEFT, fill='y', padx=10)

        # Create a frame for the timer control panel
        self.timer_frame = ttk.Frame(self.root)
        self.timer_frame.pack(side=tk.TOP, fill='x', pady=10)

        # Create buttons for the time controls
        self.backward_button = ttk.Button(self.timer_frame, text="Backward", command=self.backward)
        self.backward_button.pack(side=tk.LEFT, padx=5)

        self.forward_button = ttk.Button(self.timer_frame, text="Forward", command=self.forward)
        self.forward_button.pack(side=tk.LEFT, padx=5)

        self.reset_button = ttk.Button(self.timer_frame, text="Reset", command=self.reset)
        self.reset_button.pack(side=tk.LEFT, padx=5)

        # Create a label to display the current time on the right of the buttons
        self.time_label = ttk.Label(self.timer_frame, text=f"Current Time: {self.current_time}")
        self.time_label.pack(side=tk.RIGHT, padx=10)

        # Create a canvas for displaying draggable and resizable modules with scrollbars
        self.canvas = tk.Canvas(self.root, bg="black")
        self.canvas.pack(side=tk.RIGHT, fill='both', expand=True)

        # Add scrollbars to the canvas
        self.canvas_scrollbar_x = ttk.Scrollbar(self.root, orient='horizontal', command=self.canvas.xview)
        self.canvas_scrollbar_x.pack(side=tk.BOTTOM, fill='x')
        self.canvas_scrollbar_y = ttk.Scrollbar(self.root, orient='vertical', command=self.canvas.yview)
        self.canvas_scrollbar_y.pack(side=tk.RIGHT, fill='y')

        self.canvas.configure(xscrollcommand=self.canvas_scrollbar_x.set, yscrollcommand=self.canvas_scrollbar_y.set)

        # Initialize the VCDParser and parse the VCD file
        self.vcd_parser = VCDParser()

        file_path = '/Users/lukeb/school/2024-2025/eecs470/proj/p4-w25.group2/cpu_test.vcd'
        self.vcd_parser.parse_vcd(file_path)

        # Store module data to draw boxes for each
        self.module_boxes = {}
        self.box_offset = 10  # Offset for initial position of boxes

        # Create checkboxes for each module
        self.module_vars = {}
        for module_name in self.vcd_parser.variables.keys():
            var = tk.IntVar(value=0)  # Store checkbox state (0 = deselected, 1 = selected)
            checkbox = ttk.Checkbutton(self.module_frame, text=module_name, variable=var,
                                       command=self.update_display)
            checkbox.pack(anchor='w')
            self.module_vars[module_name] = var

    def update_display(self):
        """Update the display area based on selected checkboxes"""
        # Clear current content on canvas
        self.canvas.delete("all")

        # Draw a box for each selected module
        for module_name, var in self.module_vars.items():
            if var.get() == 1:  # If module is selected
                # Calculate the height of the box based on the number of variables
                variable_height = len(self.vcd_parser.variables[module_name]) * 20  # Height per variable (adjustable)
                box_width = 200  # Width of the box (fixed for simplicity)
                box_height = 40 + variable_height  # Minimum height + height for each variable

                # Get the current box position or use the offset if not previously moved
                if module_name not in self.module_boxes:
                    x1, y1 = self.box_offset, self.box_offset
                else:
                    x1, y1 = self.module_boxes[module_name]["x"], self.module_boxes[module_name]["y"]
                
                x2, y2 = x1 + box_width, y1 + box_height
                module_box = self.canvas.create_rectangle(x1, y1, x2, y2, fill="lightblue", outline="black", tags="resizable")

                # Create the module name text (moves with the box)
                module_name_text = self.canvas.create_text(x1 + 10, y1 + 10, text=module_name, anchor="nw")

                # Add variables inside the box (display the current time's variable values)
                variables_text = "\n".join([f"{var_info['name']}: {self.get_variable_value(var_info['name'])}" for var_info in self.vcd_parser.variables[module_name].values()])
                variables_text_id = self.canvas.create_text(x1 + 10, y1 + 30, text=variables_text, anchor="nw", font=("Arial", 8))

                # Create a resize handle at the bottom-right corner of the box
                resize_handle = self.canvas.create_rectangle(x2 - 10, y2 - 10, x2, y2, fill="gray", outline="black", tags="resizable_handle")

                # Bind the mouse events to make the box draggable and resizable
                self.canvas.tag_bind(module_box, "<ButtonPress-1>", lambda event, box=module_box, name_text=module_name_text, vars_text=variables_text_id: self.on_box_press(event, box, name_text, vars_text))
                self.canvas.tag_bind(module_box, "<B1-Motion>", lambda event, box=module_box, name_text=module_name_text, vars_text=variables_text_id: self.on_box_drag(event, box, name_text, vars_text))
                self.canvas.tag_bind(module_box, "<ButtonRelease-1>", lambda event, box=module_box: self.on_box_release(event, box))

                # Bind resizing functionality (drag the resize handle)
                self.canvas.tag_bind(resize_handle, "<B1-Motion>", lambda event, handle=resize_handle, box=module_box: self.on_box_resize(event, handle, module_name))

                # Store the box id and initial position for later use
                self.module_boxes[module_name] = {
                    "box": module_box,
                    "name_text": module_name_text,
                    "variables_text": variables_text_id,
                    "resize_handle": resize_handle,
                    "x": x1,
                    "y": y1,
                    "width": box_width,
                    "height": box_height,
                    "start_x": None,
                    "start_y": None
                }

    def get_variable_value(self, var_name):
        """Get the value of the variable based on the current time"""
        for module_name, var_info in self.vcd_parser.variables.items():
            for var_id, var_data in var_info.items():
                if var_data['name'] == var_name:
                    return self.vcd_parser.values[self.current_time].get(var_id, 'N/A')
        return 'N/A'

    def on_box_press(self, event, box, name_text, vars_text):
        """Store the initial click position for the drag"""
        # Track the initial position when the box is pressed
        module_name = next(name for name, data in self.module_boxes.items() if data["box"] == box)
        self.module_boxes[module_name]["start_x"] = event.x
        self.module_boxes[module_name]["start_y"] = event.y

    def on_box_drag(self, event, box, name_text, vars_text):
        """Move the box and the text based on mouse movement"""
        module_name = next(name for name, data in self.module_boxes.items() if data["box"] == box)
        data = self.module_boxes[module_name]

        dx = event.x - data["start_x"]
        dy = event.y - data["start_y"]

        # Move the box
        self.canvas.move(box, dx, dy)
        self.canvas.move(name_text, dx, dy)
        self.canvas.move(vars_text, dx, dy)
        self.canvas.move(data["resize_handle"], dx, dy)

        # Update the start positions for next drag
        self.module_boxes[module_name]["start_x"] = event.x
        self.module_boxes[module_name]["start_y"] = event.y

        # Update the box's new position
        self.module_boxes[module_name]["x"] += dx
        self.module_boxes[module_name]["y"] += dy

    def on_box_release(self, event, box):
        """Handle the release of the mouse button (after drag or resize)"""
        pass

    def on_box_resize(self, event, handle, module_name):
        """Handle resizing the box"""
        data = self.module_boxes[module_name]

        # Update box width and height based on the mouse position
        new_width = event.x - data["x"]
        new_height = event.y - data["y"]

        # Update the dimensions of the box if the new size is larger than the original size
        if new_width > 50 and new_height > 50:
            self.canvas.coords(data["box"], data["x"], data["y"], event.x, event.y)
            self.canvas.coords(data["name_text"], data["x"] + 10, data["y"] + 10)
            self.canvas.coords(data["variables_text"], data["x"] + 10, data["y"] + 30)
            self.canvas.coords(data["resize_handle"], event.x - 10, event.y - 10, event.x, event.y)

            # Update the stored width and height
            self.module_boxes[module_name]["width"] = new_width
            self.module_boxes[module_name]["height"] = new_height

    def forward(self):
        """Move forward in time"""
        if self.current_time_index < len(self.vcd_parser.times) - 1:
            self.current_time_index += 1
            self.current_time = self.vcd_parser.times[self.current_time_index]
            self.update_time_label()
            self.update_display()

    def backward(self):
        """Move backward in time"""
        if self.current_time_index > 0:
            self.current_time_index -= 1
            self.current_time = self.vcd_parser.times[self.current_time_index]
            self.update_time_label()
            self.update_display()

    def reset(self):
        """Reset the timer to the first time"""
        self.current_time_index = 0
        self.current_time = self.vcd_parser.times[0] if self.vcd_parser.times else 0
        self.update_time_label()
        self.update_display()

    def update_time_label(self):
        """Update the label to show the current time"""
        self.time_label.config(text=f"Current Time: {self.current_time}")


# Main code to run the application
if __name__ == "__main__":
    # Create the root window
    root = tk.Tk()

    # Create the application instance
    app = TabExplorerApp(root)

    # Start the main loop to run the GUI
    root.mainloop()
