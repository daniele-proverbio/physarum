/**
* Name: physarum
* Author: damiano reginato
* Description: behaviour of true slime mold Physarum Polycephalum in its plasmodium state
* Tags: biology, decentralied exploration, decentralised clustering
*/


model physarum

global torus: torus_environment
{
	bool torus_environment <- false;
	bool apply_avoid <- false;
	
	//parameters
	int grid_dimension <- 80; int gd <- grid_dimension;
	
	float food_quantity <- 15.0;
	float food_location_size <- 0.5;
	float food_influence_size <- 6.5;
	
	int initial_population <- 750;
	int maximum_population <- 20000;
	
	float physarum_speed <- 1.0;
	
	float initial_trail <- 1.0;
	float trail_evaporation <- 0.6;
	
	float sensor_arm_angle <- 45.0;
	float sensor_arm_length <- 3.0;
	
	//enviroment shape
    geometry shape <- square(gd);
    
    //colors
    rgb black const:true <- rgb('black');
    rgb white const:true <- rgb('white');
    rgb green const:true <- rgb('green');
    rgb red const:true <- rgb('red');
    rgb blue const:true <- rgb('blue');
    rgb light_blue const:true <- rgb('#ADD8E6');
    rgb lighter_blue const:true <- rgb('#DEEFF5');
    rgb light_sierra const:true <- rgb('#F87431');
    rgb dark_orange const:true <- rgb('#F88017');
    rgb sienna const:true <- rgb('#C35817');
    rgb chocolate const:true <- rgb('#7E2217');

    //experimentalist's measurements:


    //set agents and enviroment
    init
    {
        create physarum number: initial_population   //physarum setting
        {
             //location <- { rnd(gd - 2) + rnd(1.5), rnd(gd - 2) + rnd(1.5)};
             location <- { gd/2 + rnd(-gd/3,gd/3),gd/2 + rnd(-gd/3,gd/3) };
             heading <- rnd(359.9);
        }
        
        ask chem_cell       //bacteria setting
        {
            food <- 0.0;
        	color <- white;
        }
        
        //list<point> food_points <- [ {gd/2 , gd/8} , {gd/2 , 7*gd/8} ];
        //list<point> food_points <- [ {gd/6,gd/6} , {5*gd/6,5*gd/6} , {5*gd/6,gd/2} , {gd/6,5*gd/6} ];
        list<point> food_points <- [ {gd/5,gd/5} , {gd/5+3*gd/5,gd/5} , {gd/2,sqrt(3)*gd/4+gd/4}];
        
        int iter <- 0;
        loop times: length(food_points)
    	{
    		list<chem_cell> food_location <- (chem_cell where ( ( each distance_to (food_points at iter) ) <= food_location_size) );
			ask food_location //set food = food_quantity in each food_points
			{
				if food = 0
				{
					food <- food_quantity;
					color <- sienna;
				}
			}
			
			int iter2 <- 0;
			loop times: length(food_location) //kill all agents that spawn on the food to avoid triggering the state transformation immediately
			{
				ask physarum
				{
					if chem_cell(location) = food_location at iter2 { do die; }
				}
				iter2 <- iter2 + 1;
			}
			
			iter <- iter + 1;
    	}
    	iter <- 0;
    	loop times: length(food_points)
    	{
    		list<chem_cell> food_influence <- (chem_cell where ( ( each distance_to (food_points at iter) ) > food_location_size and
																 ( each distance_to (food_points at iter) ) < food_influence_size ) );
			ask food_influence //set weaker chemical attraction in an area around each food_points
			{
				if food = 0
				{
					food <- food_quantity / (self distance_to (food_points at iter))^3;
					color <- light_sierra;
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

    reflex stop_simulation when: (time > 10000){
		do pause;
	}
}


//set grid of food sources
grid chem_cell width: gd height: gd neighbors: 8 use_individual_shapes: false use_regular_agents: false
{
    float food <- 0.0;
    float trail <- 0.0 max: initial_trail update: trail*trail_evaporation;
    rgb color <- ( (food = food_quantity) ? sienna : ( (food < food_quantity and food > 0) ? light_sierra : ( (trail < 0.001) ? white : light_blue ) ) ) 
    			 update: ( (food = food_quantity) ? sienna : ( (food < food_quantity and food > 0) ? light_sierra : ( (trail < 0.001) ? white : ( (trail < initial_trail/2) ? lighter_blue : light_blue ) ) ) );
}
   

//species Physarum definition
species physarum skills: [moving] control: fsm schedules: shuffle(physarum)
{
   	chem_cell place update: chem_cell(location);
    bool thereIsFood update: false;
    bool iAmNetworking;
    bool iHaveCompany update: false;
    bool iCanMove update: true;
    bool iCouldCheck update: true;
    float speed update: physarum_speed; //amoeba speed
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
	rgb state_color <- green;
		
		
	reflex dieOutsideBorders   //die when outside borders
    {
       	float death <- 0.0;
       	if(location.x <= (death) or location.x >= (gd-(death)) or location.y <= (death) or location.y >= (gd-(death)))
       	{
       		do die;
      	}
    }
		
	reflex isThereFood  //check whether there is food
	{
		if( place.food = food_quantity ) { thereIsFood <- true; } else { thereIsFood <- false; }
	}
        
    //check if there is another agent in the forward direction to see if I can move
    reflex doIHaveCompany 
    {
        list<physarum> neighbours <- (self neighbors_at (1));
        	
        int iter <- 0;
		int networking_neighbours <- 0;
		point next_step <- self.location + {cos(self.heading),sin(self.heading)};
			
		loop times:length(neighbours)
		{
			if (neighbours at iter).iAmNetworking
			{
				networking_neighbours <- networking_neighbours + 1;
			}
			
			if chem_cell( (neighbours at iter).location ) = chem_cell( next_step )
			{
				iCanMove <- false;
			}
		
			iter <- iter + 1;
		}
		
       	if networking_neighbours != 0
      	{
     		iHaveCompany <- true;
    	}	
    }
    
     //deposit trail in current position    
    reflex deposit_trail when: iCanMove
    {
		chem_cell(self.location).trail <- initial_trail + chem_cell(self.location).trail;
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
       		left_chems <- left_sensor.food + left_sensor.trail;		
			right_chems <- right_sensor.food + right_sensor.trail;
			forward_chems <- forward_sensor.food + forward_sensor.trail;
       	}
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
	   		self.heading <- self.heading - 45;
			iCouldCheck <- false;
	   	}
	   	else if (rsx-gd/2)^2 + (rsy-gd/2)^2 >= (radius)^2
	   	{
	   		self.heading <- self.heading + 45;
			iCouldCheck <- false;
	   	}
	   	else if (fsx-gd/2)^2 + (fsy-gd/2)^2 >= (radius)^2
	   	{
	   		self.heading <- abs(180 - self.heading);
			iCouldCheck <- false;
		}
    }
    
    reflex amIOutOfBounds
    {	
		do check_out_of_bounds_2;
    }
    
    reflex last_shot when: !iCouldCheck
    {
    	iCouldCheck <- true;
    	do update_sensor_position;
    	do check_out_of_bounds_2;
    	do update_chems;
    }

    reflex check_chems
    {	
    	do update_chems;
    }


    //states of amoeba
    /*state exploring //initial: true     //agent moves away from chemoattractants
    {
        iAmNetworking <- false;
        transition to: networking when: (thereIsFood or iHaveCompany);
        if forward_chems > left_chems and forward_chems > right_chems
        {
        	self.heading <- self.heading;
        }
        else if right_chems > left_chems
        {
        	self.heading <- self.heading + 45;
        }
        else if right_chems < left_chems
        {
        	self.heading <- self.heading - 45;
        }
        do wander amplitude: 0.0 ;
    }*/

    state networking initial: true				  //agent moves towards chemoattractants
    {
		state_color <- red;
		iAmNetworking <- true;
		
		if forward_chems > left_chems and forward_chems > right_chems
		{
			self.heading <- self.heading;
		}
		else if right_chems > left_chems
        {
        	self.heading <- self.heading - 45;
        }
        else if right_chems < left_chems
        {
        	self.heading <- self.heading + 45;
        }
        
        do wander amplitude: 0.0;
    }

    aspect default         //aspect
    {
    	draw circle(0.5) color: state_color;
    }
} //end physarum
    

//specie obstacle
species obstacle
{
    point obstacle_location;
    aspect default { draw shape color: #gray border: #black; }
}


 //definition of the experiment
experiment Aggregation  type: gui
{
	// multiple simulations
    //float seedValue<-0.1*rnd(1000);
    //float seed<-seedValue;
    //init { create simulation with:[seed::rnd(1000)]; }

    output
    {
        display grille
        {
            grid chem_cell;
            species physarum;
            species obstacle;
        }

    }
}
