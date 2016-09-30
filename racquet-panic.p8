pico-8 cartridge // http://www.pico-8.com
version 8
__lua__
-- constants
tile_width=4
tile_height=4
num_cols=32
num_rows=21
game_top=0
game_bottom=num_rows*tile_height
game_left=0
game_right=num_cols*tile_width
game_mid=flr((num_cols/2)*tile_width)
entity_classes={
	["player"]={
		["width"]=12,
		["height"]=16,
		["init"]=function(entity,args)
			entity.x=args.x
			entity.y=args.y
			entity.is_grounded=false
			entity.state='standing'
			entity.state_frames=0
			entity.swing='forehand'
			entity.swing_power_level=1 -- min=1 max=4
			entity.swings={
				["forehand"]={
					["startup"]=2,
					["active"]=2,
					["recovery"]=6,
					["hitbox"]={3,1,20,14}, -- x1,y1,x2,y2
					["hit_dir"]={
						{1,-0.14},
						{1,-0.23},
						{1,-0.26}
					}
				}
			}
		end,
		["pre_update"]=function(entity)
			entity.vy+=0.1
			entity.state_frames+=1
			if entity.is_grounded then
				-- swing when z is pressed
				if entity.state=='standing' or entity.state=='walking' then
					if btn(4) then
						entity.state='charging'
						entity.state_frames=0
						entity.swing='forehand'
						entity.swing_power_level=2
					end
				end
				if entity.state=='charging' then
					entity.swing_power_level=min(flr(2+entity.state_frames/15),4)
					if not btn(4) then
						entity.state='swinging'
						entity.state_frames=0
					end
				end
				if entity.state=='swinging' then
					local swing = entity.swings[entity.swing]
					if entity.state_frames>=swing.startup+swing.active+swing.recovery then
						entity.state='standing'
						entity.state_frames=0
					end
				end
				-- move left/right when arrow keys are pressed
				entity.vx=0
				if entity.state=='standing' or entity.state=='walking' then
					if btn(0) then
						entity.vx-=2
					end
					if btn(1) then
						entity.vx+=2
					end
					if entity.state=='standing' and entity.vx!=0 then
						entity.state='walking'
						entity.state_frames=0
					elseif entity.state=='walking' and entity.vx==0 then
						entity.state='standing'
						entity.state_frames=0
					end
				end
			end
			entity.is_grounded=false
		end,
		["update"]=function(entity)
			entity.x+=entity.vx
			entity.y+=entity.vy
			-- land on the bottom of the play area
			if entity.y>game_bottom-entity.height then
				entity.y=game_bottom-entity.height
				entity.vy=min(entity.vy,0)
				entity.is_grounded=true
			end
			-- hit the left wall of the play area
			if entity.x<game_left then
				entity.x=game_left
				entity.vx=max(entity.vx,0)
			end
			-- hit the right wall of the play area
			if entity.x>game_mid-entity.width then
				entity.x=game_mid-entity.width
				entity.vx=min(entity.vx,0)
			end
		end,
		["post_update"]=function(entity)
			if entity.state=='swinging' then
				local swing = entity.swings[entity.swing]
				if entity.state_frames>=swing.startup and entity.state_frames<swing.startup+swing.active then
					local x=entity.x+0.5
					local y=entity.y+0.5
					local hitbox_left=x+swing.hitbox[1]
					local hitbox_right=x+swing.hitbox[3]
					local hitbox_top=y+swing.hitbox[2]
					local hitbox_bottom=y+swing.hitbox[4]
					foreach(balls, function(ball)
						local ball_left=ball.x
						local ball_right=ball.x+ball.width/2
						local ball_top=ball.y+ball.height/2
						local ball_bottom=ball.y+ball.height
						if hitbox_left<ball_right and
							ball_left<hitbox_right and
							hitbox_top<ball_bottom and
							ball_top<hitbox_bottom then
							ball.vx=swing.hit_dir[entity.swing_power_level-1][1]
							ball.vy=swing.hit_dir[entity.swing_power_level-1][2]
							freeze_frames=(entity.swing_power_level-1)*4
							entity.state_frames=swing.startup+swing.active-1
							ball.set_power_level(ball,entity.swing_power_level)
						end
					end)
				end
			end
		end,
		["draw"]=function(entity)
			local x=entity.x+0.5
			local y=entity.y+0.5
			if entity.state=='charging' or entity.state=='swinging' then
				if entity.swing_power_level<=2 then
					color(3)
				elseif entity.swing_power_level<=3 then
					color(11)
				else
					color(14)
				end
			else
				color(12)
			end
			local sprites=nil
			if entity.state=='charging' then
				sprites={74,75,90,91}
			elseif entity.state=='swinging' then
				local swing=entity.swings[entity.swing]
				if entity.state_frames<swing.startup then
					sprites={76,77,92,93}
				elseif entity.state_frames<swing.startup+swing.active then
					sprites={78,79,94,95}
					-- rectfill(x+swing.hitbox[1],y+swing.hitbox[2],x+swing.hitbox[3]-1,y+swing.hitbox[4]-1,8)
				else
					sprites={96,97,112,113}
				end
			elseif entity.vx>0 then
				if entity.state_frames%12<6 then
					sprites={66,67,82,83}
				else
					sprites={68,69,84,85}
				end
			elseif entity.vx<0 then
				if entity.state_frames%12<6 then
					sprites={70,71,86,87}
				else
					sprites={72,73,88,89}
				end
			else
				sprites={64,65,80,81}
			end
			if sprites then
				spr(sprites[1],x,y)
				spr(sprites[2],x+8,y)
				spr(sprites[3],x,y+8)
				spr(sprites[4],x+8,y+8)
			end
		end
	},
	["ball"]={
		["width"]=3,
		["height"]=3,
		["init"]=function(entity,args)
			entity.x=args.x
			entity.y=args.y
			entity.vx=args.vx
			entity.vy=args.vy
			entity.freeze_frames=0
			entity.gravity=0
			entity.power_level=4 -- min=1 max=4
			entity.num_tiles_hit=0
			entity.left_wall_bounces=0
			entity.right_wall_bounces=0
			entity.recent_court_bounces=0
			entity.vertical_energy=0.5*entity.vy*entity.vy+entity.gravity*(127-entity.y)
			entity.col_left=x_to_col(entity.x)
			entity.col_right=x_to_col(entity.x+entity.width-1)
			entity.row_top=y_to_row(entity.y)
			entity.row_bottom=y_to_row(entity.y+entity.height-1)
		end,
		["pre_update"]=function(entity)
			entity.prev_x=entity.x
			entity.prev_y=entity.y
			entity.vy+=entity.gravity
		end,
		["update"]=function(entity)
			entity.x+=entity.vx
			entity.y+=entity.vy
			check_for_tile_collisions(entity)
			-- todo this code could cause bugs if bounds get desynced
			-- hit the bottom of the play area
			if entity.y>game_bottom-entity.height then
				entity.y=game_bottom-entity.height
				if entity.vy>0 then
					if entity.x+entity.width/2<game_mid then
						entity.recent_court_bounces+=1
					end
					entity.do_bounce(entity,'bottom')
				end
			end
			-- hit the top of the play area
			if entity.y<game_top then
				entity.y=game_top
				if entity.vy<0 then
					entity.do_bounce(entity,'top')
				end
			end
			-- hit the left wall of the play area
			if entity.x<game_left then
				entity.x=game_left
				if entity.vx<0 then
					entity.recent_court_bounces=0
					entity.left_wall_bounces+=1
					entity.do_bounce(entity,'left')
				end
			end
			-- hit the right wall of the play area
			if entity.x>game_right-entity.width then
				entity.x=game_right-entity.width
				if entity.vx>0 then
					entity.recent_court_bounces=0
					entity.right_wall_bounces+=1
					entity.do_bounce(entity,'right')
				end
			end
		end,
		["post_update"]=function(entity)
		end,
		["can_collide_against_tile"]=function(entity,tile)
			return true -- return true to indicate a collision
		end,
		["on_collide_with_tiles"]=function(entity,tiles_hit,dir)
			local all_tiles_are_destructible=true
			foreach(tiles_hit,function(tile)
				if tile.is_destructible then
					tile.hp-=1
					if tile.hp<=0 then
						entity.recent_court_bounces=0
						entity.num_tiles_hit+=1
						tiles[tile.col][tile.row]=false
					end
				else
					all_tiles_are_destructible=false
				end
			end)
			-- change directions
			if dir=='left' or dir=='right' then
				if not all_tiles_are_destructible or entity.power_level<=2 then
					entity.do_bounce(entity,dir)
				end
			elseif dir=='top' or dir=='bottom' then
				if not all_tiles_are_destructible or entity.power_level<=2 then
					entity.do_bounce(entity,dir)
				end
			end
			return true -- return true to end movement
		end,
		["do_bounce"]=function(entity,dir)
			-- check to see if the power level has changed
			local new_power_level=entity.power_level
			if entity.power_level>=4 and (
				(entity.num_tiles_hit>10) or -- end if it moves through 10 tiles
				(entity.num_tiles_hit>1 and entity.recent_court_bounces>0) or -- end if it hits the court after hitting a tile
				(entity.left_wall_bounces+entity.right_wall_bounces+entity.recent_court_bounces>=2) -- end it it hits too many walls
				) then
				entity.set_power_level(entity,3)
			elseif entity.power_level==3 and (
				(entity.num_tiles_hit>10) or -- end if it moves through 10 tiles
				(entity.num_tiles_hit>1 and entity.recent_court_bounces>0) or -- end if it hits the court after hitting a tile
				(entity.left_wall_bounces+entity.right_wall_bounces+entity.recent_court_bounces>=2) -- end it it hits too many walls
				) then
				entity.set_power_level(entity,2)
			elseif entity.power_level==2 and entity.recent_court_bounces>0 and (entity.num_tiles_hit>0 or entity.left_wall_bounces+entity.right_wall_bounces>0) then
				entity.set_power_level(entity,1)
			end
			-- change velocities
			if dir=='left' or dir=='right' then
				entity.vx*=-1
			end
			if dir=='top' or dir=='bottom' then
				local v=sqrt(2*(entity.vertical_energy-entity.gravity*(127-entity.y)))
				if entity.vy>0 then
					entity.vy=-v
				else
					entity.vy=v
				end
			end
		end,
		["set_power_level"]=function(entity,power_level)
			local speeds_by_power_level={2.5,3.5,5,10}
			local gravity_by_power_level={0.05,0.04,0.03,0}
			entity.power_level=power_level
			local curr_speed=sqrt(entity.vx*entity.vx+entity.vy*entity.vy)
			if curr_speed>0 then
				entity.vx*=speeds_by_power_level[entity.power_level]/curr_speed
				entity.vy*=speeds_by_power_level[entity.power_level]/curr_speed
			end
			entity.gravity=gravity_by_power_level[entity.power_level]
			entity.vertical_energy=max(2.5,0.5*entity.vy*entity.vy+entity.gravity*(127-entity.y))
			entity.num_tiles_hit=0
			entity.left_wall_bounces=0
			entity.right_wall_bounces=0
			entity.recent_court_bounces=0
		end,
		["draw"]=function(entity)
			local x=entity.x+0.5
			local y=entity.y+0.5
			if entity.power_level<=1 then
				color(7)
			elseif entity.power_level<=2 then
				color(10)
			elseif entity.power_level<=3 then
				color(9)
			else
				color(8)
			end
			rectfill(x,y,x+entity.width-1,y+entity.height-1)
			-- line((entity.col_left-1)*tile_width-1,entity.y-5,(entity.col_left-1)*tile_width-1,entity.y+entity.height+4,7)
			-- line((entity.col_right)*tile_width,entity.y-5,(entity.col_right)*tile_width,entity.y+entity.height+4,15)
			-- line(entity.x-5,(entity.row_top-1)*tile_height-1,entity.x+entity.width+4,(entity.row_top-1)*tile_height-1,7)
			-- line(entity.x-5,(entity.row_bottom)*tile_height,entity.x+entity.width+4,(entity.row_bottom)*tile_height,15)
		end
	}
}
tile_legend={
	["x"]={
		["sprite"]=nil,
		["is_destructible"]=false,
		["hp"]=0
	},
	["g"]={
		["sprite"]=6,
		["is_destructible"]=true,
		["hp"]=1
	},
	["r"]={
		["sprite"]=7,
		["is_destructible"]=true,
		["hp"]=1
	}
}
levels={
	{
		["tile_map"]={
			"                                ",
			"                          ggg   ",
			"                         gggg   ",
			"                          ggg   ",
			"                          gggg  ",
			"                         ggggg  ",
			"                         gg ggg ",
			"                       ggg   gg ",
			"                      ggg    gg ",
			"                    rrrr     gg ",
			"                   rrrr r    gg ",
			"                   rrrr r   gg  ",
			"                   rrrrrr  ggg  ",
			"                   rrrrrr  gg   ",
			"                    rrrr rrrr   ",
			"                        rrrr r  ",
			"                        rrrr r  ",
			"                        rrrrrr  ",
			"                        rrrrrr  ",
			"                         rrrr   ",
			"                                ",
		}
	}
}


-- input vars
curr_btns={}
prev_btns={}


-- scene vars
actual_frame=0
scene=nil -- "title_screen" / "game"
scene_frame=0
bg_color=0


-- game vars
freeze_frames=0
level=nil
tiles={}
balls={}
entities={}
new_entities={}


-- top-level methods
function _init()
	init_game()
end

function _update()
	actual_frame+=1
	if actual_frame%1>0 then
		return
	end
	-- record current button presses
	prev_btns=curr_btns
	curr_btns={}
	local i
	for i=0,6 do
		curr_btns[i]=btn(i)
	end
	-- update whatever the active scene is
	scene_frame+=1
	if scene=="title_screen" then
		update_title_screen()
	elseif scene=="game" then
		update_game()
	end
end

function _draw()
	-- reset the canvas
	camera()
	rectfill(0,0,127,127,bg_color)

	-- draw the active scene
	if scene=="title_screen" then
		draw_title_screen()
	elseif scene=="game" then
		draw_game()
	end
end


-- title screen methods
function init_title_screen()
	scene="title_screen"
	scene_frame=0
	bg_color=0
end

function update_title_screen()
end

function draw_title_screen()
	-- debug
	print("title_screen",1,1,7)
end


-- game methods
function init_game()
	scene="game"
	scene_frame=0
	bg_color=1
	balls={}
	entities={}
	new_entities={}
	init_blank_tiles()
	-- load the level
	level=levels[1]
	create_tiles_from_map(level.tile_map)
	create_entity("player",{
		["x"]=30,
		["y"]=60
	})
	create_entity("ball",{
		["x"]=4,
		["y"]=58,
		["vx"]=10,
		["vy"]=0
	})
	foreach(new_entities,add_entity_to_game)
	new_entities={}
end

function update_game()
	if freeze_frames>0 then
		freeze_frames-=1
		return
	end

	-- update entities
	foreach(entities,function(entity)
		entity.frames_alive+=1
		entity.pre_update(entity)
	end)
	foreach(entities,function(entity)
		entity.update(entity)
	end)
	foreach(entities,function(entity)
		entity.post_update(entity)
	end)

	-- new entities get added at the end of the frame
	foreach(new_entities,add_entity_to_game)
	new_entities={}

	-- get rid of any dead entities
	balls=filter_list(balls,is_alive)
	entities=filter_list(entities,is_alive)
end

function draw_game()
	camera(0,-16)

	-- draw the tiles
	foreach_tile(draw_tile)

	-- draw entities
	foreach(entities,draw_entity)

	-- draw some ui
	camera()
	rectfill(0,0,127,15,0)
	rectfill(0,100,127,127,0)
end


-- tile methods
function init_blank_tiles()
	tiles={}
	local c
	for c=1,num_cols do
		tiles[c]={}
		local r
		for r=1,num_rows do
			tiles[c][r]=false
		end
	end
end

function create_tiles_from_map(map,key)
	local r
	for r=1,min(num_rows,#map) do
		local c
		for c=1,min(num_cols,#map[r]) do
			local symbol=sub(map[r],c,c)
			if symbol==" " then
				tiles[c][r]=false
			else
				tiles[c][r]=create_tile(symbol,c,r)
			end
		end
	end
end

function create_tile(symbol,col,row)
	local tile_def=tile_legend[symbol]
	return {
		["col"]=col,
		["row"]=row,
		["sprite"]=tile_def["sprite"],
		["is_destructible"]=tile_def["is_destructible"],
		["hp"]=tile_def["hp"]
	}
end

function draw_tile(tile)
	if tile.sprite!=nil then
		local x=tile_width*(tile.col-1)
		local y=tile_height*(tile.row-1)
		spr(tile.sprite,x-2,y-2)
		-- rectfill(x,y,x+tile_width-1,y+tile_height-1,7)
	end
end

function foreach_tile(func)
	local c
	for c=1,num_cols do
		if tiles[c] then
			local r
			for r=1,num_rows do
				if tiles[c][r] then
					func(tiles[c][r])
				end
			end
		end
	end
end


-- entity methods
function create_entity(class_name,args)
	local class_def=entity_classes[class_name]
	local entity={
		["class_name"]=class_name,
		-- position
		["x"]=0,
		["y"]=0,
		-- velocity
		["vx"]=0,
		["vy"]=0,
		-- size
		["width"]=class_def.width,
		["height"]=class_def.height,
		-- methods
		["pre_update"]=class_def.pre_update or noop,
		["update"]=class_def.update or noop,
		["post_update"]=class_def.post_update or noop,
		["draw"]=class_def.draw or noop,
		["can_collide_against_tile"]=class_def.can_collide_against_tile or noop,
		["on_collide_with_tiles"]=class_def.on_collide_with_tiles or noop,
		-- other properties
		["is_alive"]=true,
		["frames_alive"]=0
	}
	local k
	local v
	for k,v in pairs(class_def) do
		if not entity[k] then
			entity[k]=v
		end
	end
	if class_def.init then
		class_def.init(entity,args)
	end
	add(new_entities,entity)
	return entity
end

function add_entity_to_game(entity)
	add(entities,entity)
	if entity.class_name=="ball" then
		add(balls,entity)
	end
	return entity
end

function draw_entity(entity)
	-- rectfill(entity.x+0.5,entity.y+0.5,entity.x+0.5+entity.width-1,entity.y+0.5+entity.height-1,9)
	entity.draw(entity)
	-- print(entity.col_left,entity.x+0.5-10,entity.y+0.5,13)
	-- print(entity.row_top,entity.x+0.5,entity.y+0.5-10,13)
	-- print(entity.col_right,entity.x+0.5+entity.width-1+5,entity.y+0.5+entity.height-1,13)
	-- print(entity.row_bottom,entity.x+0.5+entity.width-1,entity.y+0.5+entity.height-1+5,13)
end

function check_for_tile_collisions(entity)
	local x=entity.prev_x
	local y=entity.prev_y
	local i
	for i=1,50 do
		local dx=entity.x-x
		local dy=entity.y-y

		-- if we are not moving, we are done
		if dx==0 and dy==0 then
			break
		end

		-- find the next vertical bound along the ball's path
		local bound_x=nil
		-- vertical bound is to the right of the ball
		if dx>0 then
			bound_x=tile_width*entity.col_right-entity.width
			x=min(x,bound_x)
		-- vertical bound is to the left of the ball
		elseif dx<0 then
			bound_x=tile_width*(entity.col_left-1)
			x=max(x,bound_x)
		end

		-- find the next horizontal bound along the ball's path
		local bound_y=nil
		-- horizontal bound is below the ball
		if dy>0 then
			bound_y=tile_height*entity.row_bottom-entity.height
			y=min(y,bound_y)
		-- horizontal bound is above the ball
		elseif dy<0 then
			bound_y=tile_height*(entity.row_top-1)
			y=max(y,bound_y)
		end

		-- ball will reach the next vertical bound first
		if bound_y==nil or (bound_x!=nil and (bound_x-x)/dx<(bound_y-y)/dy) then
			local bound_dx=bound_x-x
			local can_reach_bound=(abs(bound_dx)<=abs(dx))
			-- move to the bound
			if can_reach_bound then
				x=bound_x
				y+=dy*bound_dx/dx
			-- move to the end of the movement
			else
				x=entity.x
				y=entity.y
			end
			-- update non-leading edges
			if dy>0 then
				entity.row_top=y_to_row(y)
			elseif dy<0 then
				entity.row_bottom=y_to_row(y+entity.height-1)
			end
			if dx>0 then
				entity.col_left=x_to_col(x)
			elseif dx<0 then
				entity.col_right=x_to_col(x+entity.width-1)
			end
			if can_reach_bound then
				-- figure out what the bound's column would be
				local col
				if dx>0 then
					col=entity.col_right+1
				elseif dx<0 then
					col=entity.col_left-1
				end
				-- find all tiles that could be in the way
				local tiles_to_collide_with={}
				local row
				for row=entity.row_top,entity.row_bottom do
					if tiles[col] and tiles[col][row] and entity.can_collide_against_tile(entity,tiles[col][row]) then
						add(tiles_to_collide_with,tiles[col][row])
					end
				end
				-- collide against all of those tiles
				local dir='right'
				if dx<0 then
					dir='left'
				end
				local temp_x=entity.x
				local temp_y=entity.y
				entity.x=x
				entity.y=y
				if #tiles_to_collide_with>0 and entity.on_collide_with_tiles(entity,tiles_to_collide_with,dir) then
					break
				-- update the leading bound if we are not done yet
				else
					entity.x=temp_x
					entity.y=temp_y
					if dx>0 then
						entity.col_right=col
					elseif dx<0 then
						entity.col_left=col
					end
				end
			else
				break
			end
		-- ball will reach the next horizontal bound first
		else
			local bound_dy=bound_y-y
			local can_reach_bound=(abs(bound_dy)<=abs(dy))
			-- move to the bound
			if can_reach_bound then
				x+=dx*bound_dy/dy
				y=bound_y
			-- move to the end of the movement
			else
				x=entity.x
				y=entity.y
			end
			-- update non-leading edges
			if dy>0 then
				entity.row_top=y_to_row(y)
			elseif dy<0 then
				entity.row_bottom=y_to_row(y+entity.height-1)
			end
			if dx>0 then
				entity.col_left=x_to_col(x)
			elseif dx<0 then
				entity.col_right=x_to_col(x+entity.width-1)
			end
			if can_reach_bound then
				-- figure out what the bound's row would be
				local row
				if dy>0 then
					row=entity.row_bottom+1
				elseif dy<0 then
					row=entity.row_top-1
				end
				-- find all tiles that could be in the way
				local tiles_to_collide_with={}
				local col
				for col=entity.col_left,entity.col_right do
					if tiles[col] and tiles[col][row] and entity.can_collide_against_tile(entity,tiles[col][row]) then
						add(tiles_to_collide_with,tiles[col][row])
					end
				end
				-- collide against all of those tiles
				local dir='bottom'
				if dy<0 then
					dir='top'
				end
				local temp_x=entity.x
				local temp_y=entity.y
				entity.x=x
				entity.y=y
				if #tiles_to_collide_with>0 and entity.on_collide_with_tiles(entity,tiles_to_collide_with,dir) then
					break
				-- update the leading bound if we are not done yet
				else
					entity.x=temp_x
					entity.y=temp_y
					if dy>0 then
						entity.row_bottom=row
					elseif dy<0 then
						entity.row_top=row
					end
				end
			else
				break
			end
		end
	end
	entity.x=x
	entity.y=y
end


-- helper methods
function noop() end

function btnp2(i)
	return curr_btns[i] and not prev_btns[i]
end

function ceil(n)
	return -flr(-n)
end

function filter_list(list,func)
	local l={}
	local i
	for i=1,#list do
		if func(list[i]) then
			add(l,list[i])
		end
	end
	return l
end

function is_alive(x)
	return x.is_alive
end

function is_colliding(x1,y1,w1,h1,x2,y2,w2,h2)
	return x1<=x2+w2-1 and x2<=x1+w1-1 and y1<=y2+h2-1 and y2<=y1+h1-1
end

function x_to_col(x)
	return flr(x/tile_width)+1
end

function y_to_row(y)
	return flr(y/tile_height)+1
end


__gfx__
22222222222222222222222200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2888888888888888888ee88200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2888e888888ee88888e88e82000000000000000000dd550000aaab0000eee80000eee80000aaa900000000000066650000000000000000000000000000000000
288ee88888e88e888888e882000000000000000000d5d50000abbb0000e8880000e8880000a99900000000000066560000000000000000000000000000000000
2888e8888888e88888888e820000000000000000005d550000bbb300008882000088820000999400000000000065650000000000000000000000000000000000
2888e888888e888888e88e8200004444444000000055550000b333000082220000822200009444000000000000555500000000000000c00000c0000000000000
2888e88888eeee88888ee882000044444440000000000000000000000000000000000000000000000000000000000000000000000000ccccccc0000000000000
288888888888888888888882000044744740000000000000000000000000000000000000000000000000000000000000000000000000cc1cc1c0000000000000
288888888888888888888882000044744740000000000000000000000000000000000000000000000000000000000000000000000000cc1cc1c0000000000000
28888e8888eeee88888ee882000044444440000000000000000000000000000000000000000000000000000000000000000000000000ccccccc0000000000000
288e8e8888e8888888e88882000000440000000000d66d0000cccc0000aaa90000766700007666000066dd000076d6000049a400000000cc0000000000000000
288e8e8888eee8888eee8882077708888000000000665d0000c00c0000a999000067750000677500006dd60000d76d000099a90000000cccc000000000000000
28eeee8888888e888e88e8827000777880000000006d6d0000c00c0000999400006775000067560000d6dd00006d7600009a990000000cccc000000000000000
28888e8888e88e888e88e882700078888000000000d5d50000cccc0000944400007556000056750000dddd0000d66d00004a940000000cccc000000000000000
28888e88888ee88888ee88820777088880000000000000000000000000000000000000000000000000000000000000000000000000000cccc000000000000000
2888888888888888888888820000040040000000000000000000000000000000000000000000000000000000000000000000000000000c00c000000000000000
28888888888888888888888200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
28888888888ee888888ee88200000000000000000000000000000000000000000000000000000000000000000000000000004000400000000000000000000000
288eeee888e88e8888e88e8200000000000000000077d50000ab3b0000aaab00006d6d00006d560000dddd00006aa60000004000400000000000000000000000
288888e8888ee88888e88e820000000000000000006d170000b3330000abbb0000d6660000655d0000dddd0000a66b0000004000400000000000000000000000
288888e888e88e88888eee820000c00000c0000000d1d10000333b0000bbb3000066d6000055d60000dddd0000b6b30000004000400000000000000000000000
28888e8888e88e8888888e820000ccccccc000000015760000b3bb0000b33300006dd600006d6d0000dddd0000b36300000ffeeeefff00000000000000000000
2888e888888ee88888888e820000ccccccc000000000000000000000000000000000000000000000000000000000000000f2ff5ee5f2f0000000000000000000
2888888888888888888888820000cc7cc7c00000000000000000000000000000000000000000000000000000000000000000ff5fe5f000000000000000000000
2888888888888888888888820000cc7cc7c00000000000000000000000000000000000000000000000000000000000000000fffffeff00000000000000000000
288e88e88888888888e88e820000ccccccc00000000000000000000000000000000000000000000000000000000000000000ffffffff00000000000000000000
28ee8e8e888e88e88ee8e8e2000000cc000000000000000000aaab0000777c00006666000066660000666500000000000000004fffff00000000000000000000
288e8e8e88ee8ee888e888e207770cccc00000000000000000abbb00007ccc00006ddd0000665500006565000000000000000f44400000000000000000000000
288e8e8e888e88e888e88e827777777cc00000000000000000bbb30000ccc100006dd60000656500005655000000000000000ffff00000000000000000000000
288e88e8888e88e888e8eee277777cccc00000000000000000b3330000c1110000d6dd0000555500005555000000000000000ffff00000000000000000000000
28888888888888888888888207770cccc00000000000000000000000000000000000000000000000000000000000000000000ffff00000000000000000000000
22222222222222222222222200000c00c00000000000000000000000000000000000000000000000000000000000000000000400400000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000c00000c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000c00000c000000000ccccccc000000000c00000c00000000c00000c000000000c00000c00000007700000c0000000000c00000c0000000000c00000c00000
0000ccccccc000000000cc1cc1c000000000ccccccc00000000ccccccc000000000ccccccc0000007777ccccc0000000000ccccccc0000000000ccccccc00000
0000cc1cc1c000000000cc1cc1c000000000cc1cc1c00000000cc1cc1c000000000cc1cc1c00000077771cc1c0000000000cc1cc1c0000000000cc1cc1c00000
0000cc1cc1c000000000ccccccc000000000cc1cc1c00000000cc1cc1c000000000cc1cc1c00000077771cc1c0000000000cc1cc1c0000000000cc1cc1c00000
0000ccccccc00000000000cc000000000000ccccccc00000000ccccccc000000000ccccccc000000077cccccc0000000077ccccccc0000000000ccccccc00000
000000cc0000000000000cccc0000000000000cc00000000000000cc00000000000000cc000000000070cc000000000077770cc00000000000000cc770000000
00000cccc000000000000cccc000000000000cccc000000000000cccc000000000000cccc0000000007cccc0000000007777cccc0000000000000cc777000000
00000cccc000000000000cccc000000000000cccc000000000000cccc000000000000cccc0000000000cccc00000000007777ccc0000000000000cc777700000
00000cccc000000000000ccccc00000000000cccc000000000000cccc000000000000cccc00000000000cccc000000000000c7cc0000000000000cccc7700000
00000cccc00000000000c0000000000000000cccc000000000000cccc000000000000cccc00000000000cccc000000000000cccc0000000000000cccc0000000
00000c00c000000000000000000000000000000c00000000000000000c0000000000000c000000000000c000c00000000000c000c00000000000c000c0000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000c00000c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c00000c0000
00000ccccccc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c00000c000000000ccccccc0000
00000cc1cc1c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ccccccc000000000cc1cc1c0000
00000cc1cc1c07700000000000000000000000000000000000000000000000000000000000000000000000000000000000000cc1cc1c000000000cc1cc1c0000
00000ccccccc77770000000000000000000000000000000000000000000000000000000000000000000000000000000000000cc1cc1c000000000ccccccc0000
0000000cc0077777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cc00000000000000cc0000000
000000cccc07777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cccc000000000000cccc070000
000000cccc70000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cccc000000000000cc77700000
000000cccc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cccc000000000000c777700000
00000ccccc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cccc000000000000c777700000
000000000c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c000c00000000000c0777000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000c00000c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000c00000c000000000ccccccc000000000c00000c00000000c00000c000000000c00000c00000007700000c0000000000c00000c0000000000c00000c00000
0000ccccccc000000000cc1cc1c000000000ccccccc00000000ccccccc000000000ccccccc0000007777ccccc0000000000ccccccc0000000000ccccccc00000
0000cc1cc1c000000000cc1cc1c000000000cc1cc1c00000000cc1cc1c000000000cc1cc1c00000077771cc1c0000000000cc1cc1c0000000000cc1cc1c00000
0000cc1cc1c000000000ccccccc000000000cc1cc1c00000000cc1cc1c000000000cc1cc1c00000077771cc1c0000000000cc1cc1c0000000000cc1cc1c00000
0000ccccccc00000000000cc000000000000ccccccc00000000ccccccc000000000ccccccc000000077cccccc0000000077ccccccc0000000000ccccccc00000
000000cc0000000000000cccc0000000000000cc00000000000000cc00000000000000cc000000000070cc000000000077770cc00000000000000cc770000000
00000cccc000000000000cccc000000000000cccc000000000000cccc000000000000cccc0000000007cccc0000000007777cccc0000000000000cc777000000
00000cccc000000000000cccc000000000000cccc000000000000cccc000000000000cccc0000000000cccc00000000007777ccc0000000000000cc777700000
00000cccc000000000000ccccc00000000000cccc000000000000cccc000000000000cccc00000000000cccc000000000000c7cc0000000000000cccc7700000
00000cccc00000000000c0000000000000000cccc000000000000cccc000000000000cccc00000000000cccc000000000000cccc0000000000000cccc0000000
00000c00c000000000000000000000000000000c00000000000000000c0000000000000c000000000000c000c00000000000c000c00000000000c000c0000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000c00000c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000ccccccc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000cc1cc1c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000cc1cc1c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000c00000c0000000000000000cc1cc1c0000000000000000000000000000000000000000000000000000000000000000000000000000000000c00000c0000
00000ccccccc0000000000000000ccccccc000000000000000000000000000000000000000000000000000000000000000000c00000c000000000ccccccc0000
00000cc1cc1c00000000000000000ccc000000000000000000000000000000000000000000000000000000000000000000000ccccccc000000000cc1cc1c0000
00000cc1cc1c0770000000000000ccccc00000000000000000000000000000000000000000000000000000000000000000000cc1cc1c000000000cc1cc1c0000
00000ccccccc7777000000000000cccccc0000000000000000000000000000000000000000000000000000000000000000000cc1cc1c000000000ccccccc0000
0000000cc0077777000000000000cccccc000000000000000000000000000000000000000000000000000000000000000000000cc00000000000000cc0000000
000000cccc077770000000000000cccccc00000000000000000000000000000000000000000000000000000000000000000000cccc000000000000cccc070000
000000cccc700000000000000000cccccc00000000000000000000000000000000000000000000000000000000000000000000cccc000000000000cc77700000
000000cccc000000000000000000cccccc00000000000000000000000000000000000000000000000000000000000000000000cccc000000000000c777700000
00000ccccc000000000000000000cc00cc00000000000000000000000000000000000000000000000000000000000000000000cccc000000000000c777700000
000000000c000000000000000000c0000c0000000000000000000000000000000000000000000000000000000000000000000c000c00000000000c0777000000
__gff__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344

