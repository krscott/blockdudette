pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- main

-- filename to record inputs.
-- set to nil to disable
rec_inp_fn="inputs.txt"
if rec_inp_fn then
	printh("",rec_inp_fn,true)
end

-- loop functions
function _init()
	cls()
	
	state={
		mode="game",
		dmap={}
	}
	
	state_init_funcs={
		game=game_init,
	}
	
	state_update_funcs={
		game=game_update,
	}
	
	state_draw_funcs={
		game=game_draw,
	}
	
	state=({
		game=game_init,
	})[state.mode](state)
	assert(state!=nil)
end

function btnp_rec(i)
	local out=btnp(i)
	if rec_inp_fn and out then
		--add(recorded_inputs,i)
		debug("rec",i)
		printh(tostr(i),rec_inp_fn)
	end
	return out
end

function input(spec)
	local any=false
	
	local function btnp2(i)
		if spec!=nil then
			return spec[i]
		else
			return btnp_rec(i)
		end
	end
	
	local function axis(i,v)
		if btnp2(i) then
			any=true
			return v
		else
			return 0
		end
	end
	
	local function bool(i)
		if btnp2(i) then
			any=true
			return true
		else
			return false
		end
	end
	
	return {
		h=axis(⬅️,-1)+axis(➡️,1),
		v=axis(⬆️,-1)+axis(⬇️,1),
		o=bool(🅾️),
		x=bool(❎),
		any=any,
	}
end

function parse_mapf(f,r)
	local out={}
	for y=0,127 do
		for x=0,127 do
			local s=mget(x,y)
			local obj=f(s,x,y)
			if obj!=nil then
				add(out,obj)
				if r!=nil then
					mset(x,y,r)
				end
			end
		end
	end
	return out
end

function parse_map(s,r)
	local function f(map_s,x,y)
		if (map_s==s) then
			return {x=x,y=y}
		end
	end
	return parse_mapf(f,r)
end

function update_map(dmap)
	for a in all(dmap) do
		mset(a.x,a.y,a.s)
	end
end

function reload_map()
	reload(0x2000,0x2000,0x1000)
end

function _update60()
	local last_mode=state.mode
	
	state.input=input()

	state=state_update_funcs
		[state.mode](state)
	assert(state!=nil)
	
	if last_mode!=state.mode then
 	state=state_init_funcs
 		[state.mode](state)
		assert(state!=nil)
	end
	
	update_map(state.dmap)
	
	if state.reload_map==true then
		reload_map()
	end
	
	if state.cam == nil then
		camera(0,0)
	else
		camera(
			state.cam.x,
			state.cam.y
		)
	end
	state.dmap={}
end

function _draw()
	state_draw_funcs
		[state.mode](state)
	
	draw_debug()
end

-->8
-- game state

-- colors
cl_light=6
cl_dark=5

-- sprites
sp_air=1
sp_brick=2
sp_block=3
sp_pl=4
sp_door=5
sp_pl2=6
sp_evt0=48
sp_evt_max=59

function game_init(state)
	local plxy=
		last(parse_map(sp_pl,sp_air))
		
	local blocks=xy_to_2d(
		parse_map(sp_block,sp_air),
		function(o) return true end
	)
	
	local function map_evt(s,x,y)
		if s>=sp_evt0 
				and s<=sp_evt_max	then
			return {x=x,y=y,n=s-sp_evt0}
		end
	end
	local triggers=xy_to_2d(
		parse_mapf(map_evt,sp_air)
	)
	
	local pl=pl_set_chkpt({
		s=sp_pl,
		x=plxy.x,
		y=plxy.y,
		right=false, --face right
		carry=false, --carry block
		hidden=false,
		input=input({})
	})
	
	return cp(state,{
		-- init player object
		pl=pl,
		pl2=cp(pl,{
			s=sp_pl2,
			hidden=true,
		}),
		blocks=blocks,
		blocks_reset=blocks,
		triggers=triggers,
		events={},
		chkpt_state={},
		chkpts_hit={},
	})
end

function game_update(state)
	local inp=state.input
	local pl=cp(state.pl,{
		input=state.input
	})
	local pl2=state.pl2
	local blocks=state.blocks

	if inp.x then
		-- reset player to checkpoint
		--[[
		return cp(state,{
			blocks=state.blocks_reset,
			pl=pl_fall(
				cp(pl,{
					x=pl.chkpt.x,
					y=pl.chkpt.y,
					carry=false
				}),
				state.blocks_reset
			),
		}, state.chkpt_state)
		--]]
		return cp(state,
			state.chkpt_state)
	end
	
	local npl,tmp_blx=
		next_pl_blx(pl,blocks)
	assert(npl)
	assert(tmp_blx)
	local tmp_pl2,nblx=
		next_pl_blx(pl2,tmp_blx)
	assert(tmp_pl2)
	assert(nblx)
	
	local npl2=cp(tmp_pl2,{
		input=input({})
	})
	
	debug("pl2",
		npl2.x..","..npl2.y)
	
	local nevts=trig_evt(
		state.triggers,
		npl,
		state.events
	)

	local nstate=proc_evts(
		cp(state,{
 		pl=npl,
 		pl2=npl2,
 		blocks=nblx,
 		events=nevts,
 		cam={
 			x=g2w(npl.x-8),
 			y=g2w(npl.y-8)
 		},
 	})
 )
 
	if pl.chkpt!=npl.chkpt then
		local is_hit=get2d(
			nstate.chkpts_hit,
			npl.chkpt.x,npl.chkpt.y
		)
		
		if is_hit==nil then
			local nchkpts_hit=set2d(
 			nstate.chkpts_hit,
 			npl.chkpt.x,npl.chkpt.y,
 			true
 		)
		
 		return cp(nstate,{
 			chkpt_state=cp(
  			fpdel(
   			nstate,"chkpt_state"
   		),{
   			chkpts_hit=nchkpts_hit
  			}
  		),
  		chkpts_hit=nchkpts_hit
  	})
  else
  	return nstate
  end
  
	else
		-- do nothing
		return nstate
	end
end

function game_draw(state)
	local pls={state.pl,state.pl2}
	local cam=state.cam
	local blx=state.blocks
	
	cls(cl_light)
	map(0,0,0,0,128,64)
	
	-- event sprites (debug)
	for x,y,v in 
			all2d(state.triggers) do
		if state.events[v.n]==nil then
 		spr(
 			sp_evt0+v.n,g2w(x),g2w(y)
 		)
 	end
	end
	
	for pl in all(pls) do
  if not pl.hidden then
 		-- player sprite
  	spr(
  		pl.s,
  		g2w(pl.x),g2w(pl.y),
  		1,1,
  		pl.right
  	)
  	
  	-- carry block sprite
  	if pl.carry then
  		spr(
  			sp_block,
  			g2w(pl.x),g2w(pl.y-1)
  		)
  	end
  end
	end
	
	-- block sprites
	for x,y,v in all2d(blx) do
		spr(sp_block,g2w(x),g2w(y))
	end
end

function g2w(g)
	return g*8
end

function is_air(blx,x,y)
	assert(blx)
	local sp=mget(x,y)
	return fget(sp,0)
		and get2d(blx,x,y)==nil
end

function is_door(x,y)
	return mget(x,y)==sp_door
end

function is_walkable(blx,x,y)
	return get2d(blx,x,y)==nil
		and (
			is_air(blx,x,y)
			or is_door(x,y)
		)
end

function fall(blx,xy)
	-- drop object to ground
	local x=xy.x
	local y=xy.y
	
	if is_air(blx,x,y+1) then
		return fall(blx,
			cp(xy,{y=y+1}))
	else
		return xy
	end
end

function try_pickup(pl,blx)
	if pl.carry then
		return pl,blx
	end
	
	local pu_x=pickup_x(pl)
	
	if get2d(blx,pu_x,pl.y)
			and is_air(blx,pu_x,pl.y-1)
			and is_air(blx,pl.x,pl.y-1)
			then		
		return cp(pl,{carry=true}),
		 clr2d(blx,pu_x,pl.y)
	else
		return pl,blx
	end
end

function try_drop(pl,blx)
	if not pl.carry then
		return pl,blx
	end
	
	local pu_x=pickup_x(pl)
	
	if is_air(blx,pu_x,pl.y-1)
			then
			
		local xy=fall(blx,{
			x=pu_x,y=pl.y-1
		})
			
		return cp(pl,{carry=false}),
		 set2d(blx,xy.x,xy.y,true)
	else
		return pl,blx
	end
end

function next_pl_blx(pl,blx)
	local inp=pl.input
	
	if inp.v>0 then
		if pl.carry then
			return try_drop(pl,blx)
		else
			return try_pickup(pl,blx)
		end
	elseif inp.h!=0 
			or inp.v!=0 then
		local dx,dy=next_dxy(pl,inp)
		local npl=pl_move(
			pl,blx,dx,dy)
		
		return cp(npl,{
 		right=next_right(pl,inp.h)
 	}),blx
 else
 	return pl,blx
	end
	
end

function next_dxy(pl,inp)
	-- find dx,dy based on input.
	-- result needs to be checked
	-- for collision
	local dx,dy
	
	if inp.v<0 then
		dx=pl.right and 1 or -1
		dy=-1
	else
		dx=inp.h
		dy=0
	end
	
	return dx,dy
end

function pl_move(
		pl,blx,dx,dy
)
	if not is_walkable(blx,
				pl.x+dx,pl.y+dy
			) then
		-- no update
		return pl
	end
	
	if pl.carry 
			and	not is_walkable(blx,
				pl.x+dx,pl.y+dy-1
			) then
		-- no update
		return pl
	end
	
	if pl.carry and dy<0
			and not is_walkable(blx,
				pl.x,pl.y-2
			) then
		-- no update
		return pl
	end 
	
	-- move player
	return pl_fall(cp(pl,{
		x=pl.x+dx,
		y=pl.y+dy
	}),blx)
end

function pl_fall(pl,blx)
	-- drop player to ground,
	-- track checkpoint if hit
	local x=pl.x
	local y=pl.y
	
	local plcp=pl_try_chkpt(pl)
	
	if is_door(x,y+1) 
			or is_air(blx,x,y+1) then
		return pl_fall(cp(plcp,{
			y=y+1
		}),blx)
	else
		return plcp
	end
end

function pl_try_chkpt(pl)
	-- if player hit checkpoint,
	-- save state in pl.chkpt
	
	if is_door(pl.x,pl.y) then
		return pl_set_chkpt(pl)
	else
		return pl
	end
end

function pl_set_chkpt(pl)
	debug("chkpt",pl.x..","..pl.y)
	return cp(pl,{
		chkpt={x=pl.x,y=pl.y}
	})
end

function pickup_x(pl)
	-- find pickup target x coord
	if pl.right then
		return pl.x+1
	else
		return pl.x-1
	end
end

function next_right(pl,h)
	-- return true if player
	-- will face right next tick
	if h<0 then
		return false
	elseif h>0 then
		return true
	else
		return pl.right
	end
end

function trig_evt(trgs,xy,evts)
	local trig=get2d(
		trgs,xy.x,xy.y
	)
	if trig and evts[trig.n]==nil
		 then
		return cp(
			stop_events(evts),
			{
 			[trig.n]={
 				n=trig.n,
 				frame=0,
 				x=xy.x,
 				y=xy.y,
 			}
 		}
 	)
	else
		return evts
	end
end

function proc_evts(state)
	local evts=state.events
	
	-- hack: clear pl2 input
 local tmp_st=cp(state,{
		pl2=cp(state.pl2,{
			input=input({})
		})
	})
	
	for i,evt in pairs(evts) do
		if not evt.done then
 		tmp_st,nevt=
 			event_f[i](tmp_st,evt)
 		
 		if nevt!=nil then
 			tmp_st=cp(tmp_st,{
 				events=cp(tmp_st.events,{
 					[i]=nevt
 				})
 			})
 		end
 	end
	end
	
	return tmp_st
end
-->8
-- events

anim_time=10

anims={
	[0]={
		0,3,0,1,3,2,2,1,3,1,0,3,2,2,
		0,0,
	},
	[1]={
 	1,1,1,1,0,3,0,1,3,0,0,0,1,3,
 	1,0,3,1,1,1,1,1,1,1,1,1,1,
	},
	[2]={
		1,3,0,3,1,1,1,1,1,1,1,1,1,1,
		1,1,1,1,1,
	},
	[3]={
		0,3,0,0,0,1,1,1,1,1,1,1,1,1,
	},
}

event_f={

	[0]=function (state,evt)
		return anim_event(
			state,evt,85,26,false
		)
	end,
	
	[1]=function (state,evt)
		return anim_event(
			state,evt,83,22,true
		)
	end,
	
	[2]=function (state,evt)
		return anim_event(
			state,evt,95,25,true
		)
	end,
	
	[3]=function (state,evt)
		return anim_event(
			state,evt,67,34,false
		)
	end,
	
}

function anim_event(
	state,evt,x,y,hide,carry
)
	local last_fr=
		#anims[evt.n]*anim_time+1

	local nstate
	if evt.frame==0 then
		nstate=cp(state,{
			pl2=cp(state.pl2,{
				x=x,
				y=y,
				hidden=false,
				carry=(not not carry),
			})
		})
	elseif evt.frame>=last_fr then
		nstate=cp(state,{
			pl2=cp(state.pl2,{
				hidden=(not not hide),
			})
		})
	else
		nstate=state
	end
	
	return animate(nstate,evt)
end

function animate(state,evt)
	local fr=evt.frame
 local kfr=fr/anim_time
 local anim=anims[evt.n]
	
	if kfr>#anim then
		return state,cp(evt,{
			done=true
		})
	end
	
	local nevt=cp(evt,{
		frame=fr+1
	})
	
	if fr%anim_time!=0 
			or anim[kfr]==nil	then
		return state,nevt
	end
	
	local pl2inp=input({
		[anim[kfr]]=true
	})
	
	return cp(state,{
		pl2=cp(state.pl2,{
			input=pl2inp
		})
	}),nevt
end

function stop_events(evts)
	return fpmap(
		function (evt)
			return cp(evt,{done=true})
		end,
		evts
	)
end
-->8
-- test state

function test_init(state)
	function a(x)
		print("a")
		return x+1
	end
	
	function b(x)
		print("b")
		return x/2
	end
	
	print(compose(a,b,1))
	
	return state
end
-->8
-- debug

-- set to false to disable
debug_en=true

debug_s={}

debug_x=1
debug_y=1
debug_color=8

function debug(k,v)
	if debug_en then
		debug_s[k]=v
	end
end

function debug_clr(k)
	debug(i,nil)
end

function draw_debug()
	local y=debug_y
	
	camera()
	
	for k,v in pairs(debug_s) do
		if v!=nil then
			print(k..":"..tostr(v),
				debug_x,y,debug_color)
			y+=6
		end
	end
	
	if y>debug_y then
		-- place cursor below debug
		print("",0,y)
	end
end
-->8
-- notes
--[[

todo
----
. improve event stopping
. improve checkpoint state
		reloading


sprite flags
------------
0: air

--]]
-->8
-- fp helpers

-- copy and update objects
function cp(...)
 local	obj = {}
	for o in all({...}) do
		for k,v in pairs(o) do
			obj[k] = v
		end
	end
	return obj
end

-- remove key from table
function fpdel(tbl,key)
 local	obj = {}
	for k,v in pairs(tbl) do
		if k!=key then
			obj[k] = v
		end
	end
	return obj
end

-- call all right-to-left
function compose(...)
	local args = {...}
	local x=args[#args]
	
	for i = (#args-1),1,-1 do
		x=args[i](x)
	end
	
	return x
end

-- get sign of number
function sign(x)
	if x<0 then
		return -1
	elseif x>0 then
		return 1
	else
		return 0
	end
end

-- table mapping
function fpmap(f,tbl)
	local out={}
	for k,v in pairs(tbl) do
		out[k]=f(tbl[k])
	end
	return out
end

-- call f on each char in str
function each_ch(s,f)
	for i=1,#s do
		f(sub(s,i,i))
	end
end

-- concat array
function concat(a,b)
	local out={}
	for v in all(a) do
		add(out,v)
	end
	for v in all(b) do
		add(out,v)
	end
	return out
end

-- add to array
function fpadd(a,x)
	return concat(a,{x})
end

function set2d(a,i,j,v)
	local new_i={[j]=v}
	
	if a[i]!=nil then
		new_i=cp(a[i],new_i)
	end
	
	return cp(a,{
		[i]=new_i
	})
end

function clr2d(a,i,j)
	if a[i]==nil then
		return a
	else
		local ai=cp(a[i])
		ai[j]=nil
		return cp(a,{[i]=ai})
	end
end

function get2d(a,i,j)
	if a[i]==nil then
		return nil
	else
		return a[i][j]
	end
end

function all2d(a)
	local arr={}
	for i,ai in pairs(a) do
		for j,v in pairs(ai) do
			if v!=nil then
				add(arr,{i,j,v})
			end
		end
	end
	
	-- iterator
	local i=0
	return function()
		i+=1
		if i<=#arr then
			return arr[i][1],
				arr[i][2],
				arr[i][3]
		end
	end
end

function xy_to_2d(arr, f)
	local out={}
	for obj in all(arr) do
		local fobj=(
			f!=nil and f(obj) or obj
		)
		out=set2d(
			out,obj.x,obj.y,fobj
		)
	end
	return out
end

function last(arr)
	return arr[#arr]
end
__gfx__
00000000666666665555565555555555665555566555555666655566000000000000000000000000000000000000000000000000000000000000000000000000
00000000666666665555565556666665656665556566665665555556000000000000000000000000000000000000000000000000000000000000000000000000
00000000666666666666666656666665655656556566665666656656000000000000000000000000000000000000000000000000000000000000000000000000
00000000666666665555555656666665656666556566665666566656000000000000000000000000000000000000000000000000000000000000000000000000
00000000666666665555555656666665665555556566655666656566000000000000000000000000000000000000000000000000000000000000000000000000
00000000666666666666666656666665665665566566665666565656000000000000000000000000000000000000000000000000000000000000000000000000
00000000666666665555565556666665665555666566665666665666000000000000000000000000000000000000000000000000000000000000000000000000
00000000666666665555565555555555665665666555555666656566000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555555555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5eeeeee55bbbbbb50000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5eeeeee55bbbbbb50000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5eeeeee55bbbbbb50000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5eeeeee55bbbbbb50000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5eeeeee55bbbbbb50000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5eeeeee55bbbbbb50000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555555555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8888888899999999aaaaaaaabbbbbbbbccccccccddddddddeeeeeeeeffffffff1111111122222222333333334444444400000000000000000000000000000000
8888888899999999aaaaaaaabbbbbbbbccccccccddddddddeeeeeeeeffffffff1111111122222222333333334444444400000000000000000000000000000000
8888555899995599aaaa555abbbb555bcccc5c5cdddd555deeee5eeeffff555f1111555122225552553355535544554400000000000000000000000000000000
8888585899999599aaaaaa5abbbbbb5bcccc5c5cdddd5dddeeee5eeeffffff5f1111515122225252353353534544454400000000000000000000000000000000
8888585899999599aaaa555abbbbb55bcccc555cdddd555deeee555effffff5f1111555122225552353353534544454400000000000000000000000000000000
8888585899999599aaaa5aaabbbbbb5bcccccc5cdddddd5deeee5e5effffff5f1111515122222252353353534544454400000000000000000000000000000000
8888555899995559aaaa555abbbb555bcccccc5cdddd555deeee555effffff5f1111555122222252555355535554555400000000000000000000000000000000
8888888899999999aaaaaaaabbbbbbbbccccccccddddddddeeeeeeeeffffffff1111111122222222333333334444444400000000000000000000000000000000
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
10101010101010101010101010202020202020202020202020202030101010101010101010103010101010101010101010101020202020202010101010101010
10101010101010101010101010101010101010101020202020202020202020202020202020202020202020201010101020202020101010101010101010101010
10101010101010101010101010101010101020202020202020202020203010101010101010103010101010101010101010102020202020202020201010101010
10101010101010101010101010101010101010101010202020202020202020202020202020202020202020101010102020202020101010101010101010101010
10101010101010101010101010101010101010101010101020202020202020202020202020202020202020202020202020202020202020202020202020201010
10103010101010101010202020202020202020101010102020202020202020202020202020202020202010101010202020202020101010101010101010101010
10101010101010101010101010101010101010101010101010101020202020202020202020202020202020202020202020202020101010102020202020202010
10102020202020202020202020202020202020201010101020202020202020202020202020202020201010101020202020202020101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101020202020202010
10102020202020202020202020202020202020202010101010202020202010101010101010101010101010102020202020202020101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010102020202020
10202020202020202020202020202020202020202020101010102020202010101010101010101010101010202020202020202020201010101010102020101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101020202020
10202020202020202020202020202020202020202020201010101010102010103010102020202020202020202020202020202020202020202020202020201010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101020202020
10102020202020202020202020202020202020202020202010101010101010102010101020202020202020202020202020202020202020202020202020201010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101020202020
10102020202020202020202020202020202020202020202020202020202020202020101010201010101010101010101010101010101010101010102020101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101020202020
20102020202020202020202020202020202020202020202020201010101020202020201010201010101010101010101010101010101010101010102020101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10101010101010101010101010101010101010101010101010101030101010102020202010501010101010101010101010101010101010101010102020101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101030101010
10101010101010101010101010334010101010101010101010102020201010102020202020201010101010101010101010101010101010101010102020101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010102020202020
20202020201010101043202020202010102010101010202010101010101010102020202020201010101010101010101010101010101010101010102020101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101020202020
20202020201010101010202020202020102030101010202010303010101010101010101010501010101010101010101010101010101030101010102020101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010202020
20202020201010101010202020202020202030101010202010302020202020202020202020200210101010101010301010101010301020201010102020101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010102020
20202020202020202020202020202020202020202020202020202020202020202020202020201010103010101010201010101010201010101010302020101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101020
20202020202020202020202020202020202020202020202020202020202020202020202020201010102010101010101010103010101010101020202020101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
20202020202020202020202020202020202020202020202020202020202020202020202020201010101010101030101010102010101010101010102020101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
20202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020201010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010101010102020202020202020202020202020202020202020202020202020201010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010101010101020201010101010101010101010101010101010101010102020101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
__gff__
0001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010202020101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101
0101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101020202020201010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101
0101010101010101010101010101010101010101010101010101010301010101010101010101010101010101010101010101010101010101010101010101010101010101010102020202020202010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101
0101010101020202010101010101010101010101010101010101020202010101010101010101010101010101010101010101010101010101010101010101010101010101010203020302030203020101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101
0101010102020202020101010101010101010101010101010102020202020101010101010101010101010101010101010101010101010101010103010101010101010101020202020202020202020201010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101
0101010102010101020101010101010101010201010101010102010101020101010101010101010101010101010101010101010101010101010202020101010101010101020201010101010101020201010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101
0101010102010401050101010102030101010203010101010105010101020101010101010101010101010101010101010101010101010101020203020201010101010101050101010101010101010201010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101
0101010102020202020202020202020202020202020201010202020102020202020101010101010101010101010101010101010101010102020302030202010101010101020202020202020201010102010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101
0101010101010102020202020202020201010101010202010202010101020202020201010101010101010101010101010101010101010202020202020202020101010101020101010101010201010201010101010101010201010101010101010101010101010101010101010101010101010101010101010101010101010101
0101010101010101020202020101020101010101010102020201010101020202010101010101010101010101010101010101010101010201010101010101020101010101020101010101010201010102010101010101010201010101010101010101010101010101010101010101010101010101010101010101010101010101
0101010101010101010202020101020101010101010101020101010101010102010101010103010301030103010301030103010101010501010101010101010101010101010101010301010103010201010101010101020202010101010101010101010101010101010101010101010101010101010201010101010101010101
0101010101010101010202010101010101010101010101010101010101010302020202020202020202020202020202020202020202020202020201010103020202020202020102020202020202020201010101010102020202020101010101010101010101010101010101010101010101010101020202010101010101010101
0101010101010101010202010202020101010101010101010101010101020202020201010101010101010101010101010101010102020201010101010302020201010102020102010101020203020101010101010202030302020201010101010101010101010101010101010101010101010102020302020101010101010101
0101010101010101020202010202020101010101010101010101030101020202010101010101010101010101010101010101010101010203010101020202020101010101020101010102020302010101010101010202030203020201010101010101010101010101010101010101010101010101020202010101010101010101
0101010101010101020202010501020101030303020201020202020202020101010101010101010101010101010101010101010101010202010101010101020101010101020102010301020201010101010101010202030302020201010101010101010101010101010101010101010101010101010201010101010101010101
0101010101010102020202020201020202020202020201020201020201010101010101010101010101010103010103010101010101010202020201010103020101010202020102020201020101010101010101010202030203020202010101010101010101010101010101010101010101010101030203010101010101010101
0101010101010102020201010101010101010101010201020101010202030301010101010101010101010202010202010202010101010101010101030102020101010102020202020201020101010101010101010202030302020202020202020202020202020202020202020202020201010102020202010101010101010101
0101010101010102020101010101010101010101010202020101010102020303010101010101010101010101010101010101020101010103010101020202020101010101020101010201020101010101010101010202020202020202020202020202020202020202020202020202020101010202020202010101010101010101
0101010101010202020101020101010201010101010101010101010101020203030101010101010103010101010101010101010101010202030101010101020101010101020103010501020101010101010101010202020202020202020101010101010101010101010101010101010101020202020202010101010101010101
0101010101010201050101020101010101010301010101010101010101010202030101010101010202020102020102020101010101010202020201010103020101010103020102020202020201010101010101020202020202020101010101010101010101010101010101010101010102020202020202010101010101010101
0101010101020201020102020202020202020201010101010101010103020202020303010101020101010101010101010101010101030201010101010302020101010202010101010101010201010101010101020202010101010101020201010101010101010102010101010101010101010202010102010101010101010101
0101010101020201020102020101010101010202010101020101010302020202020202020202020202020202020202020202020202020203010101020202020101010101030101010101030101010101010101010201010101010102020101010101020101010202030101010101010101010102010103010101010101010101
0101010101020201020202010101010101010102020101010101030202020202020202020202020202020202020202020202020202020202030101010101020101010101030101010101030101013001310101010501010101010202010101010102020301010202030301010101010101010101010102010101010101010101
0101010102020101010201010101010102010101020202020202020201010102010101020101010201010102010101020101010201010102020201010103020202020202020202020202020202010201020102020202010132020201010102020202020303020202030303010202020202020202020202020202020202020202
0101010102010101010101010102020102010101020102020201020202010101010101020301010101010202020102020201020202010202010101010302020201010102020302030203020202200120012002010101010103020101010101010202020202020202020202020202020202020202020201010101010101010101
0101010102010101010101010101020202010101020101020101010201010101010303020301010101010102010101010101010101010102010101020202020101010101010202020202020202010101010102010101020202020101010101010101020101010101010202020202020202020202020101010101010101010101
0101010102010101010103010301010102010101020101010101010201010101020202020202010301010101010101010101010101010102030101010101020101010101010101020202020202030303030302030101010132010101010120020103010101010101010102020202020202020202010101010101010101010101
0101010102030101010302010201020101010103020202010101010101010102020101010101020301010101010101030302010201010102020201010103020101010101010101010102020202020202020202020202020202020202020202020202020202020201010101020202020202020202010101010101010101010101
0101010102020103010202020201020102010303050102010101010101010102010101010101020202020101010102020202010201010101050101010302020101010101010101010101010202020202020202020202020202020202020202020202020202020202010101010202020202020202010101010101010101010101
0101010101020202020202020202020102020202020101010101010101010101010101010101010501010101010301010101010201010102020202020202010101010101010101010101010101020202020202020202020202020202020202020202020202020202020101010102020202020202010101010101010101010101
0101010101010202020202020202020202020202020101010103010102020201020202010202020203010101010301010101010101010102020202020101010101010101010101010101010101010101020202020202020202020202020202020202020202020202020201010101020202020202010101010101010101010101
0101010101010101010202020202020202020202020202020202030101010101010101010101010202020202020201010101010102020202020201010101010101010101010101010101010101010101020202020202020202020202020202020202020202020202020202010101010202020202010101010101010101010101
