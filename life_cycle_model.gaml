
model physarum

global torus: torus_environment
{
	bool torus_environment <- false;
	
	//parameters
	int grid_dimension <- 80; int gd <- grid_dimension;
	
	float food_quantity <- 15.0; float fq <- food_quantity;
	float food_influence_size <- 7.0; float fis <- food_influence_size;
	
	int initial_population <- 100;
	
	float physarum_speed <- 0.7;
	
	float base_trail <- 1.0; float bt <- base_trail;
	float max_trail <- 3.0; float mt <- max_trail; //TODO: sensitivity analysis
	float trail_evaporation <- 0.7; float te <- trail_evaporation; //TODO: sensitivity analysis
	
	float sensor_arm_angle <- 45.0;
	float sensor_arm_length <- 2.0;
	
	int cooldown <- 3;
	int birth_density <- 2;
	int death_density <- 18;
	
	int starvation_threshold <- 50;
	int death_threshold_init <- 250;
	
	int stop_cycle <- 3000;
	
	//enviroment shape
    geometry shape <- square(gd);
    
    //colors
    rgb black const:true <- rgb('black');
    rgb white const:true <- rgb('white');
    rgb green const:true <- rgb('green');
    rgb red const:true <- rgb('red');
    rgb blue const:true <- rgb('blue');
    rgb light_blue const:true <- rgb('#ADD8E6'); rgb lb <- light_blue;
    rgb lighter_blue const:true <- rgb('#DEEFF5'); rgb llb <- lighter_blue;
    rgb light_sierra const:true <- rgb('#F87431'); rgb ls <- light_sierra;
    rgb dark_orange const:true <- rgb('#F88017');
    rgb sienna const:true <- rgb('#C35817');
    rgb chocolate const:true <- rgb('#7E2217');
    rgb flax const:true <- rgb("#E3D985");

    //experimentalist's measurements:
    
	int population update: length(physarum);
	int exploring_population;
	int networking_population;
	
	int perturbation <- 0;
	int grid_resolution <- 11; int gr <- grid_resolution;
	matrix connection_matrix <- 0 as_matrix({gr,gr});
	matrix visited <- 0 as_matrix({gr,gr});
	bool flag <- true;
	float grid_side <- (3*gd/4)/gr; float gs <- grid_side;
	int score <- 0;
	list<int> ten_scores <- [];
	
	
reflex build_connection_matrix when: cycle = stop_cycle-1
	{
		loop i from: 0 to: gr-1 
		{ 
    		loop j from: 0 to: gr-1
    		{
    			if (physarum count (each.location.y >= gd/8 + i*gs and each.location.y < gd/8 + (i+1)*gs and
			                		each.location.x >= gd/8 + j*gs and each.location.x < gd/8 + (j+1)*gs)) != 0
			    {
			    	put 1 in: connection_matrix at: i*gr + j;
			    }
    		}
		}
		
		// if cycle = stop_cycle { write connection_matrix; }
	}
	
	bool is_safe(int i, int j, int k)
	{
		if i >= 0+k and i <= gr-1-k and j >= 0 and j <= gr-1 
		{
			return true;
		} else {
			return false;
		}
	}
	
	bool build_path(matrix con_mat, matrix vis_mat, int i, int j, int k)
	{
		if is_safe(i,j,k) and !vis_mat[i,j] and con_mat[i,j]
		{
			vis_mat[i,j] <- 1;
			if i = int((gr-1)/2) and j = gr-1 { flag <- true; return true; }
				
			bool up <- build_path (con_mat, vis_mat, i-1, j, k);
			if up {return true;}
				
			bool down <- build_path (con_mat, vis_mat, i+1, j, k);
			if down {return true;}
				
			bool left <- build_path (con_mat, vis_mat, i, j-1, k);
			if left {return true;}
				
			bool right <- build_path (con_mat, vis_mat, i, j+1, k);
			if right {return true;}
			
			bool up_left <- build_path (con_mat, vis_mat, i-1, j-1, k);
			if up_left {return true;}
				
			bool down_left <- build_path (con_mat, vis_mat, i+1, j-1, k);
			if down_left {return true;}
				
			bool up_right <- build_path (con_mat, vis_mat, i-1, j+1, k);
			if up_right {return true;}
				
			bool down_right <- build_path (con_mat, vis_mat, i+1, j+1, k);
			if down_right {return true;}
		}
		else { flag <- false; }
	}
	
	reflex score_check when: cycle = stop_cycle - 1
	{
		score <- 0;
		
		loop k from: 0 to: (gr-1)/2
		{
			visited <- 0 as_matrix({gr,gr});
			
			if connection_matrix[int((gr-1)/2),0] = 0 or connection_matrix[int((gr-1)/2),gr-1] = 0 
			{ break; }
			else
			{ do build_path (connection_matrix, visited, int((gr-1)/2), 0, k); }
				
			if flag { score <- score + 1; }
			else if !flag { break; }
		}
	}
	
	//food point definition
	
	list<point> food_points <- [ {gd/2 , gd/6} , {gd/2 , 5*gd/6} ];

    //set agents and enviroment
    init
    {    	
        create physarum number: initial_population   //physarum setting
        {
             geometry spawn <- circle(gd/25,{gd/2,gd/2});             
             location <- any_location_in(spawn);
             heading <- rnd(359.9);
             speed <- physarum_speed + rnd(-0.05*perturbation,0.05*perturbation);
        }
        
        ask chem_cell       //bacteria setting
        {
            food <- 0.0;
        	color <- white;
        }
        
        int iter <- 0;
    	loop times: length(food_points)
    	{
    		list<chem_cell> food_influence <- (chem_cell where ( ( each distance_to (food_points at iter) ) < food_influence_size ) );
			ask food_influence //set chemical attraction in an area around each food_points
			{
				if food = 0
				{
					food <- food_quantity / (1+(self distance_to (food_points at iter))^2);
					//color <- light_sierra;
					rf <- 12478/49 - 6500*food/(49*food_quantity);
					gf <- 6787/49 - 3700*food/(49*food_quantity);
					bf <- 3950/49 - 3950*food/(49*food_quantity);
					color <- rgb(rf,gf,bf);
				}
			}
			
			int iter2 <- 0;
			loop times: length(food_influence) //kill all agents that spawn on the food to avoid triggering the state transformation immediately
			{
				ask physarum
				{
					if chem_cell(location) = food_influence at iter2 { do die; }
				}
				iter2 <- iter2 + 1;
			}
			
			iter <- iter + 1;
    	}
    	
    }
    
	bool take_pics <- false;
	bool save_data <- false;

	string base <- "insertRootHere";
	string pic_destination <- base + "/LCM/" + gr + "/";
	string score_destination <- base + "/LCM/population/";
	
	reflex snapshot when: (cycle mod 1 = 0) and take_pics
   	{
		save (snapshot(self,"grille",{1000,1000})) to: pic_destination + "/grille/cycle_" + cycle + ".png";
		save (snapshot(self,"chart_population",{1000,1000})) to: pic_destination + "/chart/cycle_" + cycle + ".png";
	}
	 
	reflex save_data when: cycle = stop_cycle - 1 and save_data
	{
		save score to: score_destination + "_sal.csv" format: "csv" header: false rewrite: false;
		
		save population to: score_destination + "population.csv" format: "csv" header: false rewrite: false;
		save exploring_population to: score_destination + "exploring.csv" format: "csv" header: false rewrite: false;
		save networking_population to: score_destination + "networking.csv" format: "csv" header: false rewrite: false;
	}
	
	reflex stop_simulation when: cycle = stop_cycle
   	{
		do pause;
	}
}


//set grid of food sources
grid chem_cell width: gd height: gd neighbors: 8 use_individual_shapes: false use_regular_agents: false
{
    float food;
    float trail <- 0.0 max: mt min: 0.0 update: trail*te;
    
	float rf update: 12478/49 - 6500*food/(49*food_quantity);
	float gf update: 6787/49 - 3700*food/(49*food_quantity);
	float bf update: 3950/49 - 3950*food/(49*food_quantity);
	
	float rt update: 211*trail^2/mt^2 - 422*trail/mt + 255.0;
	float gt update: 49*trail^2/mt^2 - 98*trail/mt + 255.0;
	float bt update: 255.0;
	
	rgb color <- ( (food!=0)? rgb(rf,gf,bf):rgb(rt,gt,bt) ) update: ( (food!=0)? rgb(rf,gf,bf):rgb(rt,gt,bt) );
}
   

//species Physarum definition
species physarum skills: [moving] control: fsm schedules: shuffle(physarum)
{
    int hunger <- 0;
    int local_population;
    int clock <- 0;
    int death_threshold <- death_threshold_init;
    bool thereIsFood update: false;
    bool iAmStarving <- false;
    bool iAmNetworking;
    bool iCouldCheck update: true;
    bool ready <- true;
    bool iHaveCompany update: false;
    float luck <- gauss(0,starvation_threshold/10);
    float speed <- physarum_speed; //amoeba speed TODO
    float left_chems;
    float right_chems;
    float forward_chems;
	float left_sensor_x update: self.location.x + sensor_arm_length*(cos(sensor_arm_angle)*cos(self.heading) - sin(sensor_arm_angle)*sin(self.heading));
	float left_sensor_y update: self.location.y + sensor_arm_length*(sin(sensor_arm_angle)*cos(self.heading) + cos(sensor_arm_angle)*sin(self.heading));
	float right_sensor_x update: self.location.x + sensor_arm_length*(cos(sensor_arm_angle)*cos(self.heading) + sin(sensor_arm_angle)*sin(self.heading));
	float right_sensor_y update: self.location.y + sensor_arm_length*(-sin(sensor_arm_angle)*cos(self.heading) + cos(sensor_arm_angle)*sin(self.heading));
	float forward_sensor_x update: self.location.x + sensor_arm_length*cos(self.heading);
	float forward_sensor_y update: self.location.y + sensor_arm_length*sin(self.heading);
	chem_cell left_sensor update: chem_cell({left_sensor_x,left_sensor_y});
	chem_cell right_sensor update: chem_cell({right_sensor_x,right_sensor_y});
	chem_cell forward_sensor update: chem_cell({forward_sensor_x,forward_sensor_y});
	chem_cell place update: chem_cell(location);
	rgb state_color <- green;
		
	
	//die when outside borders
	reflex die_outside_borders
    {
       	if(location.x <= 0.0 or location.x >= gd or location.y <= 0.0 or location.y >= gd)
       	{
       		do die;
      	}
    }
    
    reflex is_there_food  //check whether there is food
	{
		if( place.food != 0 )
		{ 
			thereIsFood <- true;
			hunger <- 0;
		} 
		else 
		{ 
			thereIsFood <- false;
			hunger <- hunger + 1;
		}
	}
	
    action update_sensor_position
	{
		left_sensor_x <- self.location.x + sensor_arm_length*(cos(sensor_arm_angle)*cos(self.heading) - sin(sensor_arm_angle)*sin(self.heading));
		left_sensor_y <- self.location.y + sensor_arm_length*(sin(sensor_arm_angle)*cos(self.heading) + cos(sensor_arm_angle)*sin(self.heading));
		right_sensor_x <- self.location.x + sensor_arm_length*(cos(sensor_arm_angle)*cos(self.heading) + sin(sensor_arm_angle)*sin(self.heading));
		right_sensor_y <- self.location.y + sensor_arm_length*(-sin(sensor_arm_angle)*cos(self.heading) + cos(sensor_arm_angle)*sin(self.heading));
		forward_sensor_x <- self.location.x + sensor_arm_length*cos(self.heading);
		forward_sensor_y <- self.location.y + sensor_arm_length*sin(self.heading);
		left_sensor <- chem_cell({left_sensor_x,left_sensor_y});
		right_sensor <- chem_cell({right_sensor_x,right_sensor_y});
		forward_sensor <- chem_cell({forward_sensor_x,forward_sensor_y});
	}
	
	action update_chems
    {
       	if iCouldCheck
       	{
       		float weight <- 0.5;
       		left_chems <- weight*left_sensor.food + (1-weight)*left_sensor.trail;
			right_chems <- weight*right_sensor.food + (1-weight)*right_sensor.trail;
			forward_chems <- weight*forward_sensor.food + (1-weight)*forward_sensor.trail;
       	}
    }
    
    action deposit_trail
    {
    	chem_cell(self.location).trail <- base_trail + chem_cell(self.location).trail;
    }
	
	//square boundary
    action check_out_of_bounds  //check whether one or both the sensors are out of bound and rotate accordingly
    {	
		float lsx <- left_sensor_x;    float lsy <- left_sensor_y;
	   	float rsx <- right_sensor_x;   float rsy <- right_sensor_y;
	   	float fsx <- forward_sensor_x; float fsy <- forward_sensor_y;
		float sal <- 0.0;
		if lsx <= sal or lsx >= gd - sal or lsy <= sal or lsx >= gd - sal
		{
			self.heading <- self.heading - (45 + rnd(0.0,90.0));
			iCouldCheck <- false;
		}
		else if rsx <= sal or rsx >= gd - sal or rsy <= sal or rsy >= gd - sal
		{
			self.heading <- self.heading + (45 + rnd(0.0,90.0));
			iCouldCheck <- false;
		}
		else if fsx <= sal or fsx >= gd - sal or fsy <= sal or fsy >= gd - sal
		{
			self.heading <- abs(180 - self.heading);
			iCouldCheck <- false;
		}
    }
    
    //circular boundary
    action check_out_of_bounds_2  //check whether one or both the sensors are out of bound and rotate accordingly
    {	
		float lsx <- left_sensor_x;    float lsy <- left_sensor_y;
	   	float rsx <- right_sensor_x;   float rsy <- right_sensor_y;
	   	float fsx <- forward_sensor_x; float fsy <- forward_sensor_y;
		float radius <- gd/2;
		if (lsx-gd/2)^2 + (lsy-gd/2)^2 >= (radius)^2
	   	{
	   		self.heading <- self.heading - 90;
			iCouldCheck <- false;
	   	}
	   	else if (rsx-gd/2)^2 + (rsy-gd/2)^2 >= (radius)^2
	   	{
	   		self.heading <- self.heading + 90;
			iCouldCheck <- false;
	   	}
	   	else if (fsx-gd/2)^2 + (fsy-gd/2)^2 >= (radius)^2
	   	{
	   		self.heading <- abs(180 - self.heading);
			iCouldCheck <- false;
		}
    }
    
    //check bounds, update chem values, deposit trail
    reflex pre_movement
    {
    	do check_out_of_bounds_2;
    	
		if iCouldCheck { do update_chems; }
    	
		do deposit_trail;
	}
	
	//check if any of my neighbours is networking to trigger a state change
    action do_I_have_company 
    {
        list<physarum> neighbours <- (self neighbors_at (sensor_arm_length));
        local_population <- length(neighbours);
    }
	
	//reproduce or die
	reflex live_or_die
    {
    	do do_I_have_company;
    	
    	if !ready
    	{
    		clock <- clock + 1;
    		if clock = cooldown { ready <- true; }
    	}
    	
//    	if thereIsFood and rnd(1.0) < exp(-0.01*population)
		if thereIsFood and local_population < birth_density and ready
		{
			ready <- false;
			create species(self) number: 1
			{
           		location <- myself.location;
           		heading <- rnd(359.9);
           		hunger <- 0;
            	self.state <- myself.state;
        	}
		}
		else if hunger - luck > starvation_threshold and hunger - luck <= death_threshold
		{
			iAmStarving <- true; //TODO: cambio di comportamento?
		}
		else if hunger - luck > death_threshold or local_population > death_density and cycle > 5
		{
			do die;
		}
	}	


    //states of amoeba
    state exploring initial: true     //agent moves away from chemoattractants
    {
        iAmNetworking <- false;
        transition to: networking when: iAmStarving;
        if right_chems > left_chems
        {
        	self.heading <- self.heading + 45;
        }
        else if right_chems < left_chems
        {
        	self.heading <- self.heading - 45;
        }
        else
        {
        	self.heading <- self.heading + rnd(-1.0,1.0)*45;
        }
        
        do wander amplitude: 0.0;
    }

    state networking				  //agent moves towards chemoattractants
    {
		state_color <- red;
		iAmNetworking <- true;
		
		if forward_chems > left_chems and forward_chems > right_chems
		{
			self.heading <- self.heading + rnd(-0.5,0.5)*45;
		}
		else if right_chems > left_chems
        {
        	self.heading <- self.heading - 45;
        }
        else if right_chems < left_chems
        {
        	self.heading <- self.heading + 45;
        }
        else
        {
        	self.heading <- self.heading + rnd(-1.0,1.0)*45;
        }
        
        do wander amplitude: 0.0;
    }
    
    reflex count
    {
    	if !iAmNetworking
    	{exploring_population <- exploring_population + 1;}
    	else
    	{networking_population <- networking_population + 1;}
    }

    aspect default         //aspect
    {
    	draw circle(0.5) color: state_color;
    }
} //end physarum


//definition of the experiment
experiment one_simulation type: gui
{
    output
    {
        display grille
        {
        	grid chem_cell;
        	
        	graphics "layer1" transparency: 0.8
            {
            	float offset <- gd/8 + gs/2;
            	
            	loop i from: 0 to: gr-1 
				{ 
		    		loop j from: 0 to: gr-1
		    		{
		    			draw square(gs) at: {offset + i*gs, offset + j*gs} color: white border: black;
		    		}
				}
            }
        	
            species physarum;
        }
        
        display chart_population
        {
        		chart name: "Population" type: series background: rgb("white") axes: rgb("black") position: {0,0} size: {1.0,1.0}
                {
                    data "Population" color: rgb("red") value: population style: spline ;
                }
		}
    }
}

experiment performance type: batch repeat: 100 keep_seed: false until: (cycle = stop_cycle) parallel:20  {
	int samples <- 1;
	float steps <- 0.0;
	
	parameter "sensor_arm_length" var:sensor_arm_length min:0.75 max:0.75 step:steps;
//	parameter "trail_evaporation" var:trail_evaporation min:0.9 max:0.9 step:steps;
//	parameter "speed perturbation" var:perturbation min:0 max:samples step:steps;
    method exploration sample:samples;
}
