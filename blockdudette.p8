pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- blockdudette
-- v0.9.1
-- by kris scott

-- developed as a study of
-- functional programming.

cartdata("kris_blockdudette_0")

-- record inputs
-- set to nil to disable
rec_inp_fn=nil
--rec_inp_fn="inputs.txt"
if rec_inp_fn then
	-- clear file
	printh("",rec_inp_fn,true)
end

-- button inputs
function btn_spec()

 -- 0 or 1? make up your mind!!
	local spec=fpmap(btnp,{
		[0]=0,1,2,3,4,5
	})

	--if any(spec)
	--		then
 	local str=arr_to_str(
	 	spec,true
	 )
 	--debug("rec",str)
		if rec_inp_fn then
 		printh(str..",",rec_inp_fn)
 	end
	--end
	return spec
end

-- gameloop functions
function _init()
	cls()

	state_update_funcs={
		title=title_update,
		game=game_update,
		win=win_update,
	}

	state_draw_funcs={
		title=title_draw,
		game=game_draw,
		win=win_draw,
	}

	-- call all init functions.
	-- inits should only ever be
	-- called once.
	state=compose(
		title_init,
		game_init,
		win_init,
		{
 		mode="title"
 	}
	)

	assert(state!=nil)
end

function input(spec)
	if spec==nil then
		spec=btn_spec()
	end

	local function axis(i,v)
		if spec[i] then
			return v
		else
			return 0
		end
	end

	local function bool(i)
		if spec[i] then
			return true
		else
			return false
		end
	end

	out={
		h=axis(⬅️,-1)+axis(➡️,1),
		v=axis(⬆️,-1)+axis(⬇️,1),
		o=bool(🅾️),
		x=bool(❎),
	}

	if spec==nil and rec_inp_fn
			then
		local str=obj_to_str(out)
		--debug("rec",str)
		if any then
			printh(str..",",rec_inp_fn)
		end
	end

	return out
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

function reload_map()
	reload(0x2000,0x2000,0x1000)
end

function _update60()
	local last_mode=state.mode

	state.input=input()

	state=state_update_funcs
		[state.mode](state)
	assert(state!=nil)

	if state.cam == nil then
		camera(0,0)
	else
		camera(
			state.cam.x,
			state.cam.y
		)
	end
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
sp_door_open=7
sp_heart=8

sp_evt0=48
sp_evt_max=59

-- enums
chkpt_none=0
chkpt_pl1=1
chkpt_pl2=2
chkpt_all=3

-- game objects
go_bl={
	s=sp_block,
	pickup=true,
	walkable=false,
}

no_input=input({})

function save_state(state)	
	local pldel={
		"input","chkpt"
	}
	local sst={
		pl=fpdel(state.pl,pldel),
		pl2=fpdel(state.pl2,pldel),
		coop=state.coop,
	}
	
	if debug_en then
		local ser=serialize(sst)
		debug("save file size",#ser)
	end
	
	write_persist(sst)
end

function load_state(state)
	local lst=read_persist()
	
	if lst==nil then
		return state
	end
	
	return cp(state,{
		pl=cp(state.pl,lst.pl),
		pl2=cp(state.pl2,lst.pl2),
		coop=lst.coop
	})
end

function game_init(state)
	local plxy=
		last(parse_map(sp_pl,sp_air))

	local pl2xy=last(
		parse_map(sp_pl2,sp_air)
	)

	local blocks=xy_to_2d(
		parse_map(sp_block,sp_air),
		function(o) return go_bl end
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
		hidden=false,
		walkable=true,
		input=input({})
	})
	
	local has_save_data=
		read_persist()!=nil

	return cp(state,{
		-- init player object
		pl=pl,
		pl2=cp(pl,{
			s=sp_pl2,
			x=pl2xy.x,
			y=pl2xy.y,
		}),
		blocks=blocks,
		blocks_reset=blocks,
		triggers=triggers,
		events={
			[7]={
				n=7,
				frame=0,
				x=0,
				y=0
			}
		},
		chkpt_state=nil,
		chkpts_hit={},
		coop=false,
		auto=false,
		has_save_data=has_save_data,
	})
end

function game_update(state)
	local inp=(
		state.auto
		and no_input
		or state.input
	)

	local pl=cp(state.pl,{
		input=inp
	})
	local pl2=state.pl2
	local blocks=state.blocks

	if inp.x then
		return cp(state,
			state.chkpt_state)
	end

	if inp.o	and state.coop then
		local chkpt=get2d(
			state.chkpts_hit,pl2.x,pl2.y
		)

		if chkpt==nil
				or chkpt==chkpt_none
				or chkpt==chkpt_all
				then
			return swap_players(state)
		end
	end

	local npl,npl2,nblx=
		next_pls_blx(pl,pl2,blocks)

	assert(npl)
	assert(npl2)
	assert(nblx)

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

	if nstate.chkpt_state==nil
			or pl.chkpt!=npl.chkpt then
		local chkpt_status=get2d(
			nstate.chkpts_hit,
			npl.chkpt.x,npl.chkpt.y
		)

		if chkpt_status!=chkpt_all
				then

			-- next checkpoint status
			local ncs
			if state.coop then
 			ncs=bor(
 				chkpt_status,
 				(pl.s==sp_pl
 					and chkpt_pl1
 					or chkpt_pl2
 				)
 			)
 		else
 			ncs=chkpt_all
 		end

			local nchkpts_hit=set2d(
 			nstate.chkpts_hit,
 			npl.chkpt.x,npl.chkpt.y,
 			ncs
 		)

			if ncs==chkpt_all then
				local cps=cp(
  			fpdel(
   			nstate,"chkpt_state"
   		),{
   			chkpts_hit=nchkpts_hit
  			}
  		)
  		
  		save_state(cps)
  		
  		return cp(nstate,{
  			chkpt_state=cps,
   		chkpts_hit=nchkpts_hit
   	})
   else
  		return cp(
  			swap_players(nstate),
  			{
   			chkpts_hit=nchkpts_hit
   		}
   	)
   end
  else
  	return nstate
  end

	else
		-- do nothing
		return nstate
	end
end

function game_draw(state)
	local pls={state.pl2,state.pl}
	local cam=state.cam
	local blx=state.blocks
	local chpts=state.chkpts_hit

	cls(cl_light)
	map(0,0,0,0,128,64)

	-- event sprites (debug)
	if debug_en then
 	for x,y,v in
 			all2d(state.triggers) do
 		if state.events[v.n]==nil
 				then
  		spr(
  			sp_evt0+v.n,g2w(x),g2w(y)
  		)
  	end
 	end
 end

	-- open door sprites
	for x,y,v in all2d(chpts) do
		if v==chkpt_all then
 		spr(
 			sp_door_open,g2w(x),g2w(y)
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
  	for i=1,num_carry(pl,blx)
  			do
  		spr(
  			sp_block,
  			g2w(pl.x),g2w(pl.y-i)
  		)
  	end
  end
	end

	-- block sprites
	for x,y,v in all2d(blx) do
		spr(v.s,g2w(x),g2w(y))
	end

	camera()

	-- text
	for i=0,11 do
		local evt=state.events[i]
		if evt
				and not evt.done
				and evt.text
				then
			--debug("text",evt.text)
			draw_event_text(evt.text)
		end
	end
end

function next_pls_blx(
	pl,pl2,blx
)

	-- add pl2 to blocks
	local objs=set2d(
		blx,pl2.x,pl2.y,pl2
	)

	local npl,nobjs=next_pl_blx(
		pl,objs
	)

	assert(npl)
	assert(nobjs)

	local nblx,pl2x,pl2y,_=
		find_pop2d(
			nobjs,
			function(v)
				return v.s==pl2.s
			end
		)

	local npl2=cp(pl2,{
		x=pl2x,
		y=pl2y,
		input=no_input
	})

	return npl,npl2,nblx
end

function g2w(g)
	return g*8
end

function is_air(blx,x,y)
	local sp=mget(x,y)
	return (
		fget(sp,0)
		and (
 		blx==nil
 		or get2d(blx,x,y)==nil
		)
	)
end

function is_door(x,y)
	return mget(x,y)==sp_door
end

function is_pl(pls,x,y)
	for pl in all(pls) do
		if pl.x==x and pl.y==y then
			return true
		end
	end
	return false
end

function is_walkable(blx,x,y)
	local bl=get2d(blx,x,y)
	return (
			bl==nil or bl.walkable
		)	and (
			is_air(nil,x,y)
			or is_door(x,y)
		)
end

function fall(blx,pls,o)
	-- drop object to ground
	local x=o.x
	local y=o.y

	-- stop if not air
	if not is_air(blx,x,y+1) then
		return o
	end

	-- stop if hit player
	if is_pl(pls,x,y+1) then
		return o
	end

	-- continue falling
	return fall(blx,pls,
		cp(o,{y=y+1}))
end

function try_pickup(pl,blx,pls)
	if is_carry_bl(pl,blx) then
		return blx
	end

	local pu_x=pickup_x(pl)
	local bl=get2d(blx,pu_x,pl.y)

	if bl and bl.pickup
			and is_air(blx,pu_x,pl.y-1)
			and is_air(blx,pl.x,pl.y-1)
			and
				not is_pl(pls,pu_x,pl.y-1)
			then
		return set2d(
			clr2d(blx,pu_x,pl.y),
			pl.x,
			pl.y-1,
			go_bl
		)
	else
		return blx
	end
end

function try_drop(pl,blx)
	local ncarry=num_carry(pl,blx)

	if ncarry==0	then
		return blx
	end

	local pu_x=pickup_x(pl)

	-- check if enough room for
	-- entire stack
	for i=1,ncarry	do
  if not
  			is_air(blx,pu_x,pl.y-i)
  		then
  	-- can't drop
  	return blx
  end
	end

	-- drop each block one by one
	local tmp_blx=blx
	for i=1,ncarry	do
		local o=fall(tmp_blx,pls,{
			x=pu_x,y=pl.y-i
		})
		local bl=
			get2d(tmp_blx,pl.x,pl.y-i)
		tmp_blx=set2d(
			clr2d(tmp_blx,pl.x,pl.y-i),
			o.x,o.y,bl
		)
	end

	return tmp_blx
end

function is_carry_bl(o,blx)
	return get2d(blx,o.x,o.y-1)
end

function num_carry(o,blx)
	if is_carry_bl(o,blx) then
		return 1+num_carry(
			{
				x=o.x,
				y=o.y-1
			},
			blx
		)
	else
		return 0
	end
end

function next_pl_blx(pl,blx)
	local inp=pl.input

	local npl,nblx
	if inp.v>0 then
		if is_carry_bl(pl,blx) then
			nblx=try_drop(pl,blx,pls)
			npl=pl

	 	assert(npl)
	 	assert(nblx)
		else
			nblx=try_pickup(pl,blx,pls)
			npl=pl

	 	assert(npl)
	 	assert(nblx)
		end
	elseif inp.h!=0
			or inp.v!=0 then
		local dx,dy=next_dxy(
			pl,inp,blx
		)
		npl,nblx=pl_move(
			pl,blx,dx,dy)

 	assert(npl)
 	assert(nblx)
 else
 	npl=pl
 	nblx=blx
	end

	assert(npl)
	assert(nblx)

	return cp(npl,{
 		right=next_right(pl,inp.h)
 	}),nblx
end

function next_dxy(pl,inp,blx)
	-- find dx,dy based on input.
	-- result needs to be checked
	-- for collision

	if inp.v<0 then
		local dx=pl.right and 1 or -1

		if not
				is_air(blx,pl.x+dx,pl.y)
				then
			return dx,-1
		else
			return 0,0
		end
	else
		return inp.h,0
	end

	return dx,dy
end

function pl_move(
		pl,blx,dx,dy
)
	--todo: make functional
	-- blx is not const

	-- is target space blocked?
	if not is_walkable(blx,
				pl.x+dx,pl.y+dy
			) then
		-- no update
		return pl,blx
	end

	local ncarry=num_carry(pl,blx)

	-- is taget space have enough
	-- room for carry stack?
	for i=1,ncarry	do
		if not is_walkable(blx,
 				pl.x+dx,pl.y+dy-i
 			) then
 		-- no update
 		return pl,blx
 	end
	end

	-- if moving up, check if top
	-- of stack has clearance
	if dy<0
			and not is_walkable(blx,
				pl.x,pl.y-ncarry-1
			) then
		-- no update
		return pl,blx
	end

	-- move player
	local npl=pl_fall(cp(pl,{
		x=pl.x+dx,
		y=pl.y+dy
	}),blx)

	-- move blocks
	for i=1,ncarry do
		local bl=
			get2d(blx,pl.x,pl.y-i)
		blx=clr2d(blx,pl.x,pl.y-i)
		blx=set2d(
			blx,npl.x,npl.y-i,bl
		)
	end

	return npl,blx
end

function pl_fall(pl,blx)
	-- drop player to ground,
	-- track checkpoint if hit
	local x=pl.x
	local y=pl.y

	local plcp=pl_try_chkpt(pl)

	--todo: fix carry
	local bl=get2d(blx,x,y+1)
	if is_door(x,y+1)
			or is_air(blx,x,y+1)
			or (bl and bl.walkable)
			then
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
			--stop_events(evts),
			evts,
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
			input=no_input
		})
	})

	--todo: use event queue?
	--todo: magic number:
	-- 11 == max event index
	for i=0,11 do
		local evt=evts[i]

		if evt and not evt.done then
 		tmp_st,nevt=
 			event_f[i](tmp_st,evt)

 		if nevt!=nil then
 			local npl2,npl,nblx=
 				next_pls_blx(
 					tmp_st.pl2,
 					tmp_st.pl,
 					tmp_st.blocks
 				)

 			tmp_st=cp(tmp_st,{
 				pl=npl,
 				pl2=npl2,
 				blocks=nblx,
 				events=cp(tmp_st.events,{
 					[i]=nevt
 				})
 			})

 			-- do events sequentially
 			break
 		end
 	end
	end

	return tmp_st
end

function is_carrying(pa,pb,blx)
	assert(blx)
	if pa.x!=pb.x then
		return false
	end
	local ncarry=num_carry(pa,blx)
	return (pa.y-ncarry-1==pb.y)
end

function is_carry_any(
	pl,pls,blx
)
	for pl2 in all(pls) do
		if pl!=pl2 then
			if is_carrying(pl,pl2,blx)
					then
				return true
			end
		end
	end
	return false
end

-->8
-- events

anim_time=10
textbox_time=60*3

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
		9,9,9,9,9,9,9,9,9,9,9,9,9,9,
		0,3,0,0,0,1,1,1,1,1,9,9,9,3,
		9,9,9,9,0,0,0,0,0,0,0,0,1,3,
		0,0,0,3,1
	},
	[6]={
		1,1,1,1,1,1,1,1,2,1,2,1,2,1,
	}
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

	[4]=function (state,evt)
		return text_event(
			cp(state,{
				coop=true,
			}),
			evt,
			{"press 🅾️ (z) to swap"}
		)
	end,

	[5]=function (state,evt)

		local nstate
		if state.pl.s==sp_pl2 then
			nstate=swap_players(
				state,true
			)
		else
			nstate=state
		end

		return cp(nstate,{
 			coop=false
 		}),
 		cp(evt,{
 			done=true,
 		})
	end,

	[6]=function (state,evt)
		return anim_event(
			cp(state,{
				auto=true,
				pl=cp(state.pl,{
					right=false
				}),
			}),
			evt,30,56,false,
			function (state)
				return cp(state,{
					blocks=set2d(
						state.blocks,
						45,52,
						{s=sp_heart}
					),
					mode="win",
				})
			end
		)
	end,

	[7]=function (state,evt)
		return text_event(state,evt,{
			"press ⬅️ (left) and",
			"➡️ (right) to move"
		})
	end,

	[8]=function (state,evt)
		return text_event(state,evt,{
			"press ❎ (x) to reset",
			"at last checkpoint"
		})
	end,

	[9]=function (state,evt)
		return text_event(state,evt,{
			"press ⬆️ (up) to climb"
		})
	end,

	[10]=function (state,evt)
		return text_event(state,evt,{
			"press ⬇️ (down) to pickup",
			"and drop blocks"
		})
	end,

	[11]=function (state,evt)
		return text_event(state,evt,{
			"find the exit!"
		})
	end,
}

function swap_players(
	state,swap_pos
)

	local function cp_pl(a,b)
		return cp(a,{
			x=swap_pos and a.x or b.x,
			y=swap_pos and a.y or b.y,
			s=b.s,
			right=(
				swap_pos
				and a.right
				or b.right
			),
		})
	end

	return cp(state,{
		pl=cp_pl(state.pl,state.pl2),
		pl2=cp_pl(state.pl2,state.pl)
	})
end

function anim_event(
	state,evt,x,y,hide,on_done
)
	if hide==nil then
		hide=false
	end

	local last_fr=
		#anims[evt.n]*anim_time+1

	local nstate
	if evt.frame==0 then
		nstate=cp(state,{
			pl2=cp(state.pl2,{
				x=x,
				y=y,
				hidden=false,
			})
		})
	elseif evt.frame>=last_fr then
		nstate=cp(state,{
			pl2=cp(state.pl2,{
				hidden=hide,
			})
		})
	else
		nstate=state
	end

	return animate(
		nstate,evt,on_done
	)
end

function animate(
	state,evt,on_done
)
	local fr=evt.frame
 local kfr=fr/anim_time
 local anim=anims[evt.n]

	if kfr>#anim then
		if on_done then
 		return on_done(state),
  		cp(evt,{
  			done=true
  		})
		else
 		return state,
 			cp(evt,{
 				done=true
 			})
		end
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

function text_event(
	state,evt,texts
)
	--todo: real text

	local fr=evt.frame

	if fr==0 then
		--debug("text",texts[1])
	end

	if fr>textbox_time then
		--debug("text", " ")
		return state,cp(evt,{
			done=true
		})
	end

	local nevt=cp(evt,{
		text=texts,
		frame=fr+1
	})

	return state,nevt
end

function stop_events(evts)
	return fpmap(
		function (evt)
			return cp(evt,{done=true})
		end,
		evts
	)
end

function draw_event_text(args)
 local y=80

	rect(
		0,y-2,128,y+#args*6,cl_dark
	)
	rectfill(
		0,y-1,128,y+#args*6-1,
		cl_light
	)

	for txt in all(args) do
 	local x=64-#txt*2
 	print(
 		txt,x,y,cl_dark
 	)
 	y+=6
 end
end
-->8
-- win state

function win_init(state)
	return state
end

function win_update(state)
	return state
end

function win_draw(state)
	game_draw(state)
	draw_event_text({"the end"})
end
-->8
-- debug

-- set to false to disable
debug_en=false

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
	debug(k,nil)
end

function draw_debug()
	if debug_en then
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
end
-->8
-- title state

function title_init(state)
	return state
end

function title_update(state)
	if state.input.x then
		return cp(state,{
			mode="game"
		})
	end
	
	if state.input.o
			and state.has_save_data
			then
		return cp(
			load_state(state),
			{
 			mode="game"
 		}
		)
	end

	return state
end

function title_draw(state)
	cls(cl_light)
	spr(sp_pl,60,68)
	spr(sp_block,60,60)

	local scale=3.3
	sspr(
		0,32,36,15,
		5,4,36*scale,15*scale
	)
	
	local txts={
		"by kris scott",
		"",
		"a tribute to ",
		"brandon sterner's",
		"block dude",
		"",
		"press ❎ (x) to start",
	}
	
	if state.has_save_data then
		add(txts,
			"press 🅾️ (z) to continue"
		)
	end

	draw_event_text(txts)
end
-->8
-- fp helpers

-- object to string
function obj_to_str(obj)
	local str="{"
	for k,v in pairs(obj) do
		str=(
			str
			..tostr(k)
			.."="
			..tostr(v)
			..","
		)
	end
	return str.."}"
end

-- array to string
function arr_to_str(arr,zero)
	local str="{"
	if zero then
		-- zero-index
		str=str.."[0]="
 	for i=0,#arr do
 		str=str..tostr(arr[i])..","
 	end
	else
 	for i=1,#arr do
 		str=str..tostr(arr[i])..","
 	end
	end
	return str.."}"
end

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
function fpdel(tbl,keys)
	if type(keys)!="table" then
		keys={keys,}
	end

 local	obj = {}
 
	for k,v in pairs(tbl) do
		local skip=false
		for dk in all(keys) do
			if k==dk then
				skip=true
			end
		end
		if not skip then
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

function find2d(a,f)
	for i,ai in pairs(a) do
		for j,v in pairs(ai) do
			if v!=nil then
				if f(v) then
					return i,j,v
				end
			end
		end
	end
	return nil
end

function find_pop2d(a,f)
	local i,j,v=find2d(a,f)
	return clr2d(a,i,j),i,j,v
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

function any(obj)
	for k,v in pairs(obj) do
		if v then
			return true
		end
	end
	return false
end

-->8
-- pico-8 serializer library
-- v0.1.0
-- by kris scott
--todo: handle whitespace


persist_addr=0x5e00
persist_end=0x5eff


-- error function
function modalerr(msg)
	--cls()
	print("error:")
	print(msg)
	print("")
	print(
		"press ❎ (x) to continue"
	)
	while not btn(❎) do
		flip()
	end
end


-- build character functions
chr,ord=(function ()
	-- uses upper and lower case
	local chars=
		" !\"#$%&'()*+,-./"
		.."0123456789:;<=>?"
		.."@abcdefghijklmno"
		.."pqrstuvwxyz[\\]^"
		.."_`abcdefghijklmn"
		.."opqrstuvwxyz{|}~"
	local s2c={}
	local c2s={}
	for i=1,#chars do
		local c=i+31
		local s=sub(chars,i,i)
		c2s[c]=s
		s2c[s]=c
	end
	
	local function chr(i)
		return c2s[i]
	end
	
	local function ord(c)
		return s2c[sub(c,1,1)]
	end
	
	return chr,ord
end)()

-- call f on each char in str
function each_ch(f,str)
	for i=1,#str do
		f(sub(str,i,i))
	end
end

function is_numeric(str)
	if str=="" then
		return false
	end

	for i=1,#str do
		local c=sub(str,i,i)
		
		if c=="-" then
 		if i!=1 then
 			return false
 		end
 	elseif c=="." then
 		--pass
 	elseif c>="0" and c<="9" then
 		--pass
 	else
 		return false
		end
	end
	
	return true
end

-- object to string
function serialize(obj)
	if obj==nil then
		return "nil"
	elseif type(obj)=="string"
			then
		return "\""..obj.."\""
	elseif type(obj)=="table" then
 	local str="{"
 	for k,v in pairs(obj) do
 		if type(k)!="string" then
 			k="["..tostr(k).."]"
 		end
 		if v!=nil then
  		str=(
  			str
  			..tostr(k)
  			.."="
  			..serialize(v)
  			..","
  		)
  	end
 	end
 	return str.."}"
 else
 	return tostr(obj)
 end
end

function next_char(f,str,i)
	for j=i,#str do
		if f(sub(str,j,j)) then
			return j
		end
	end
	
	return #str+1
end

function char_not_numeric(c)
	local n=ord(c)
	return not (
		(n>=ord("0") and n<=ord("9"))
		or n==ord(".")
		or n==ord("x")
		or n==ord("-")
	)
end

function deserialize(str,i)
	if i==nil then 
		i=1
	end
	
	assert(i<=#str)
	
	if sub(str,i,i+3)=="true" then
		return true,i+4
	elseif sub(str,i,i+4)=="false"
			then
		return false,i+5
	elseif sub(str,i,i+2)=="nil"
			then
		return nil,i+3
	elseif sub(str,i,i)=="\""
			then
		--todo: handle escape char
		local nc=next_char(
			function(c)
				return c=="\""
			end,
			str,
			i+1
		)
		return sub(str,i+1,nc-1),nc+1
	elseif sub(str,i,i)=="{"
			then
		
		local out={}
		local i=i+1
		
		while true do
			local c=sub(str,i,i)
			if c=="}" then
				i=i+1
				break
			end
			local ki=i
			i=next_char(
				function (c)
 				return c=="="
 			end,
 			str,
 			i+1
 		)
 		local k=sub(str,ki,i-1)
 		
 		if sub(str,ki,ki)=="[" then
 			k=deserialize(
 				sub(str,ki+1,i-2)
 			)
 		end
 		
 		local v
 		v,i=deserialize(str,i+1)
 		out[k]=v
 		
			if sub(str,i,i)=="," then
				i=i+1
			end
		end
		
		--print(serialize(out))
		
		return out,i
		
	else -- number
		local nc=next_char(
			char_not_numeric,str,i+1
		)
		--print(i)
		--print(nc)
		--print(sub(str,i,nc-1))
		return (sub(str,i,nc-1)+0),nc
	end
end

function write_persist(obj)
	local str=serialize(obj)
	
	if #str >= 0xff then
		cls()
		for k,v in pairs(obj) do
			local s=serialize(v)
			print(k..":"..#s)
		end
		print("")
		modalerr(
			"save file too big:"..#str
		)
		return
	end
	
	for i=1,#str do
		poke(
			persist_addr+i-1,
			ord(sub(str,i,i))
		)
	end
	
	-- null terminate
	poke(persist_addr+#str,0)
end

function read_persist()
	local str=""
	for addr=persist_addr,
			persist_end do
		local x=peek(addr)
		if x==0 then
			break
		end
		str=str..chr(x)
	end
	
	if str=="" then
		return nil
	end
	
	return deserialize(str)
end

-- testbench
--[[

assert(is_numeric("1"))
assert(is_numeric("0"))
assert(is_numeric("123"))
assert(is_numeric("-456"))
assert(is_numeric("951.753"))
assert(is_numeric("-1.2"))
assert(not is_numeric("a23"))
assert(not is_numeric(""))
assert(not is_numeric("1.3a"))
assert(not is_numeric("-b"))

function stest(test,...)
	local expct=""
	local str=serialize(test)
	for v in all({...}) do
		if str==v then
			return
		end
		expct=v
	end
	print("test:"..tostr(test))
	print("expect:"..expct)
	print("got:"..str)
	assert(false)
end

function dtest(test,expct)
	local out,i=deserialize(test)
	
	if out==expct
			or serialize(out)
				==serialize(expct)
			then
		
		if i-1==#test then
			return
		end
		print("i-1:"..(i-1))
		print("#test:"..#test)
	end
	
	print("test:"..test)
	print("expect:"..
		serialize(expct)
	)
	print("got:"..serialize(out))
	assert(false)
end

stest(590,"590")
stest(-123.456,"-123.456")
stest(nil,"nil")
stest(true,"true")
stest(false,"false")
stest({},"{}")
stest({a=1.2},"{a=1.2,}")
stest({b=nil},"{}")
stest({c=true},"{c=true,}")
stest({c=false},"{c=false,}")
stest(
	{foo="bar"},"{foo=\"bar\",}"
)
stest({a={b={c=123}}},
		"{a={b={c=123,},},}"
)
stest({a=1,b="foo"},
	"{a=1,b=\"foo\",}",
	"{b=\"foo\",a=1,}"
)
stest({"a",},"{[1]=\"a\",}")

dtest("654",654)
dtest("987.321",987.321)
dtest("0x123",0x123)
dtest("\"foo bar\"","foo bar")
dtest("{}",{})
dtest("nil",nil)
dtest("true",true)
dtest("false",false)

assert(
	deserialize(serialize(
		{"a","b","c"}
	))[2]=="b"
)

testobj=deserialize(serialize({
	[0]=5,
	[1]=6,
	a="foo",
	b=123,
	c=false,
	d=true,
	e={"z","y","x"},
	f={
		foo="bar",
		baz="qux",
	},
	g={foo={bar={qux=true}}}
}))

write_persist(testobj)
testobj=read_persist()
--print(serialize(testobj))

assert(testobj[0]==5)
assert(testobj[1]==6)
assert(testobj.a=="foo")
assert(testobj.b==123)
assert(testobj.c==false)
assert(testobj.d==true)
assert(testobj.e[1]=="z")
assert(testobj.e[3]=="x")
assert(testobj.f.foo=="bar")
assert(testobj.g.foo.bar.qux)


-- all passed
assert(nil)
--]]
__gfx__
00000000666666665555565555555555665555566555555666655566655555566666666666666666555555555555555500000000000000000000000000000000
00000000666666665555565556666665656665556566665665555556656555566556555665565556566666666666666500000000000000000000000000000000
00000000666666666666666656666665655656556566665666656656656655565465546556655665565556666666666500000000000000000000000000000000
00000000666666665555555656666665656666556566665666566656656655565445444556656665565566565656555500000000000000000000000000000000
00000000666666665555555656666665665555556566655666656566656555565444444556666665565666656656656500000000000000000000000000000000
00000000666666666666666656666665665665566566665666565656656655566544445665666656565556565656656500000000000000000000000000000000
00000000666666665555565556666665665555666566665666665666656555566654456666566566566666666666666500000000000000000000000000000000
00000000666666665555565555555555665665666555555666556556655555566665566666655666555555555555555500000000000000000000000000000000
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
66666555555555655555555555555556666666666666666666666666666666660000000000000000000000000000000000000000000000000000000000000000
66666566665665656666566665656656666666666666666666666666666666660000000000000000000000000000000000000000000000000000000000000000
66666565665665656566566665666656666666666666666666666666666666660000000000000000000000000000000000000000000000000000000000000000
66666566655665556566566555666556666666666666666666666666666666660000000000000000000000000000000000000000000000000000000000000000
66666565665666656566566665666656666666666666666666666666666666660000000000000000000000000000000000000000000000000000000000000000
66666566665666656666566665656656666666666666666666666666666666660000000000000000000000000000000000000000000000000000000000000000
66666555555555555555555555555556666666666666666666666666666666660000000000000000000000000000000000000000000000000000000000000000
66666666666666666666666666666666666666666666666666666666666666660000000000000000000000000000000000000000000000000000000000000000
55555555555555555555555555555555555566666666666666666666666666660000000000000000000000000000000000000000000000000000000000000000
56665565665666556666566665666656666566666666666666666666666666660000000000000000000000000000000000000000000000000000000000000000
56666565665666656655566665666656655566666666666666666666666666660000000000000000000000000000000000000000000000000000000000000000
56566565665656656665556655566556665666666666666666666666666666660000000000000000000000000000000000000000000000000000000000000000
56566566665656656655556656566556655566666666666666666666666666660000000000000000000000000000000000000000000000000000000000000000
56666566665666656666556656566556666566666666666666666666666666660000000000000000000000000000000000000000000000000000000000000000
55555555555555555555555556555555555566666666666666666666666666660000000000000000000000000000000000000000000000000000000000000000
66666666666666666666666666666666666666666666666666666666666666660000000000000000000000000000000000000000000000000000000000000000
66666666666666666666666666666666666666666666666666666666666666660000000000000000000000000000000000000000000000000000000000000000
66666666666666666666666666666666666666666666666666666666666666660000000000000000000000000000000000000000000000000000000000000000
66666666666666666666666666666666666666666666666666666666666666660000000000000000000000000000000000000000000000000000000000000000
66666666666666666666666666666666666666666666666666666666666666660000000000000000000000000000000000000000000000000000000000000000
66666666666666666666666666666666666666666666666666666666666666660000000000000000000000000000000000000000000000000000000000000000
66666666666666666666666666666666666666666666666666666666666666660000000000000000000000000000000000000000000000000000000000000000
66666666666666666666666666666666666666666666666666666666666666660000000000000000000000000000000000000000000000000000000000000000
66666666666666666666666666666666666666666666666666666666666666660000000000000000000000000000000000000000000000000000000000000000
66666666666666666666666666666666666666666666666666666666666666660000000000000000000000000000000000000000000000000000000000000000
66666666666666666666666666666666666666666666666666666666666666660000000000000000000000000000000000000000000000000000000000000000
66666666666666666666666666666666666666666666666666666666666666660000000000000000000000000000000000000000000000000000000000000000
66666666666666666666666666666666666666666666666666666666666666660000000000000000000000000000000000000000000000000000000000000000
66666666666666666666666666666666666666666666666666666666666666660000000000000000000000000000000000000000000000000000000000000000
66666666666666666666666666666666666666666666666666666666666666660000000000000000000000000000000000000000000000000000000000000000
66666666666666666666666666666666666666666666666666666666666666660000000000000000000000000000000000000000000000000000000000000000
66666666666666666666666666666666666666666666666666666666666666660000000000000000000000000000000000000000000000000000000000000000
10101010101010202020202020202020202020202020202020202030101010101010101010103010101010101010101010101020202020202010101010101010
10101010101010101010101010101010101010101020202020202020202020202020202020202020202020201010101020202020101010101010101010101010
10101010101010102010101010101010101020202020202020202020203010101010101010103010101010101010101010102020202020202020201010101010
10101010101010101010101010101010101010101010202020202020202020202020202020202020202020101010102020202020101010101010101010101010
10101010101010102010101010101010101010101020202020202020202020202020202020202020202020202020202020202020202020202020202020201010
10103010101010101010202020202020202020101010102020202020202020202020202020202020202010101010202020202020101010101010101010101010
10101010101010102010101010101010101010101020202020202020202020202020202020202020202020202020202020202020202020202020202020202010
10202020202020202020202020202020202020201010101020202020202020202020202020202020201010101020202020202020101010101010101010101010
10101010101010102010101010101010101010303020201010101010102020201010101010101010101020202020202020202020202020202020202020202010
10202020202020202020202020202020202020202010101010202020202010101010101010101010101010102020202020202020101010101010101010101010
10101010101010105010101010101030101020202020101010101010101020101010101010101010101010202020202020202020202020202020202020202020
10102020202020202020202020202020202020202020101010102020202010101010101010101010101010202020202020202020201010101010102020101010
10101010101020202010101010102020201010101010101010101010101050101030101010101010101010202020201010101010102020202020202020202020
10102020202020202020202020202020202020202020201010101010102010103010102020202020202020202020202020202020202020202020202020201010
10101010101010202030101010101010101010101010101020101010101020101020201010303010101010102020101010101010101020202020202020202020
20101010101010202020202020202020202020202020202010101010101010102010101020202020202020202020202020202020202020202020202020201010
10101020101010102030301020101010101010101010202020101010101020101010102010202020101010102010101010303010101010201010101010101010
10101010101010202020202020202020202020202020202020202020202020202020101010201010101010101010101010101010101010101010102020101010
10101020101010102020202020202020202020202020202020103010202020101010101010101010101010105010101010202020101010201010101010101010
20202020202010202020202020202020202020202020202020201010101020202020201010201010101010101010101010101010101010101010102020101010
10101020101010101020202020202020201010101010202020202020202020202020202010101010102020202020101010101010101010501010101010101020
20101010101010101010101010102010101010101010101010101030101010102020202010501010101010101010101010101010101010101010102020101010
10102020202010103020202020202010101010101010101020202020202020202020202020103010202020202020103010101010202020201010101010433010
10101010101010101010101010335010101010101010101010102020201010102020202020201010101010101010101010101010101010101010102020101010
10202010101010102020202020101010101010101010101010101010202020202020202020202020202020202020102020202020202020202010202020202020
20202020201010101010102020202010102010101010202010101010101010102020202020201010101010101010101010101010101010101010102020101010
10201010101010302020202020101010101010102020202020202010202020202010101010202020202020202020202020202020202020202010202020202020
20202020203010101010202020202020102030101010202010303010101010101010101010501010101010101010101010101010101030101010102020101010
10201010201020202020202020301010101010101010101010102010102020201010101010102020202020302020203020202020201010102020202020202020
20202020203010101020202020202020202030101010202010302020202020202020202020201010101010101010301010101010301020201010102020101010
10201010101020202020202020303010101010101010101010102010101020101010101010101020202030202020202030202020101010101010101010102020
20202020203020202020202020202020202020202020202020202020202020202020202020201010103010101010201010101010201010101010302020101010
10201010101020202020202020202020101010101010101010102010101020101010101010101020203020302010203020302020101010101010101010101020
20202020202020202020202020202020202020202020202020202020202020202020202020201010102010101010101010103010101010101020202020101010
10201020202020202020202020101010101010102010101010102010101020101010101010101020302030201010102030203020101010101010101010101010
20202020202020202020202020202020202020202020202020202020202020202020202020201010101010101030101010102010101010101010102020101010
10201010101010101010101020101010101010101010101030302010101020101010101010101020203020101010101020302020101010101010101010101010
20202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020201010
10201010101030101010101020303010101010101010102020202010101020101010101010101020102010101010101010201020101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010101010102020202020202020202020202020202020202020202020202020201010
10201010102020101020101020202020101010101010101010102010101020101010101010101020101010101010101010101020101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010101010101020201010101010101010101010101010101010101010102020101010
10201010201010101020101010201010101010101010103010102010101020101010101010101020101010101010631010101020101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
102010101010101010201010102030101010101010101020202020101010a0b01010101010101010101010202020202010101010101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10201010101010101020101010202020101010101010101010102010101020101010101010101010102020203030302020201010101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10201010101010101010301010501010101010101010101010301030101050531010101010101020202030302020203030202020101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202010101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10202020202020202020202020202020202020202020202020202020202020202020201010101010101010101010101010101010101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10202020202020202020202020202020202020202020202020202020202020202010101010101010101010101010101010101010101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10202020202020202020202020202020202020202020202020202020202020201010101010101010101010101010101010101010101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10202020202020202020202020202020202020202020202020202020202020101010101010101010101010101010101010101010101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10202020202020202020202020202020202020202020202020202020202020101010101010101010101010101010101010101010101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10202020202020202020202020202020202020202020202020202020202020101010101010101010101010101010101010101010101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
__gff__
0001000000000000010100000000000000000000000000000000000000000000000000000000000000000000000000000101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010202020101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010106
0101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101020202020201010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101
0101010101010101010101010101010101010101010101010101010301010101010101010101010101010101010101010101010101010101010101010101010101010101010102020202020202010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101
0101010101020202010101010101010101010101010101010101020202010101010101010101010101010101010101010101010101010101010101010101010101010101010203020302030203020101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101
0101010102020202020101010101010101010101010101010102020202020101010101010101010101010101010101010101010101010101010103010101010101010101020202020202020202020201010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101
0101010102013701020101010101010101010201010101010102010101020101010101010101010101010101010101010101010101010101010202020101010101010101020201010101010101020201010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101
01010101020104010538010139023a0301010203010101013b05010101020101010101010101010101010101010101010101010101010101020203020201010101010101050101010101010101010201010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101
0101010102020202020202020202020202020202020201010202020102020202020101010101010101010101010101010101010101010102020302030202010101010101020202020202020201010102010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101
0101010101010102020202020202020201010101010202010202010101020202020201010101010101010101010101010101010101010202020202020202020101010101020101010101010201010201010101010101010201010101010101010101010101010101010101010101010101010101010101010101010101010101
0101010101010101020202020101020101010101010102020201010101020202010101010101010101010101010101010101010101010201010101010101020101010101020101010101010201010102010101010101010201010101010101010101010101010101010101010101010101010101010101010101010101010101
0101010101010101010202020101020101010101010101020101010101010102010101010103010301030103010301030103010101010501010101010101010101010101010101010301010103010201010101010101020202010101010101010101010101010101010101010101010101010101010201010101010101010101
0101010101010101010202010101010101010101010101010101010101010302020202020202020202020202020202020202020202020202020201010103020202020202020102020202020202020201010101010102020202020101010101010101010101010101010101010101010101010101020202010101010101010101
0101010101010101010202010202020101010101010101010101010101020202020201010101010101010101010101010101010102020201010101010302020201010102020102010101020203020101010101010202030302020201010101010101010101010101010101010101010101010102020302020101010101010101
0101010101010101020202010202020101010101010101010101030101020202010101010101010101010101010101010101010101010203010101020202020101010101020101010102020302010101010101010202030203020201010101010101010101010101010101010101010101010101020202010101010101010101
0101010101010101020202010501020101030303020201020202020202020101010101010101010101010101010101010101010101010202010101010101020101010101020102010301020201010101010101010202030302020201010101010101010101010101010101010101010101010101010201010101010101010101
0101010101010102020202020201020202020202020201020201020201010101010101010101010101010103010101010101010101010202020201010103020101010202020102020201020101010101010101010202030203020202010101010101010101010101010101010101010101010101030203010101010101010101
0101010101010102020201010101010101010101010201020101010202010101010101010101010101010202010202010202010101010101010101030102020101010102020202020201020101010101010101010202030302020202020202020202020202020202020202020202020201010102020202010101010101010101
0101010101010102020101010101010101010101010202020101010102020101010101010101010101010101010101010101010101010103010101020202020101010101020101010201020101010101010101010202020202020202020202020202020202020202020202020202020101010202020202010101010101010101
0101010101010202020101020101010201010101010101010101010101020201030101010101010103010101010101010101010101010202030101010101020101010101020103010501020101010101010101010202020202020202020101010101010101010101010101010101010101020202020202010101010101010101
0101010101010201050101020101010101010301010101010101010101010202030101010101010202020102020102020101010101010202020201010103020101010103020102020202020201010101010101020202020202020101010101010101010101010101010101010101010102020202020202010101010101010101
0101010101020201020102020202020202020201010101010101010103020202020303010101020101010101010101010101010101030201010101050302020101010202010101010101010201010101010101020202010101010101020201010101010101010102010101010101010101010202010102010101010101010101
0101010101020201020102020101010101010202010101020101010302020202020202020202020202020202020202020202020202020203010101020202020101010101030101010101030101010101010101010201010101010102020101010101020101010202030101010101010101010102010103010101010101010101
0101010101020201020202010101010101010102020101010101030202020202020202020202020202020202020202020202020202020202030101010101020101010101030101010101030101013001310101010501010101010202010101010102020301010202030301010101010101010101010102010101010101010101
0101010102020101010201010101010102010101020202020202020201010102010101020101010201010102010101020101010201010102020201010103020202020202020202020202020202010201020102020202010132020201010102020202020303020202030303010202020202020202020202020202020202020202
0101010102010101010101010102020102010101020102020201020202010101010101020301010101010202020102020201020202010202010101010302020201010102020302030203020202010101010102010101010103020101010101010202020202020202020202020202020202020202020201010101010101010101
0101010102010101010101010101020202010101020101020101010201010101010303020301010101010102010101010101010101010102010101020202020101010101010202020202020202010101010102010101020202020101010101010101020101010101010202020202020202020202020101010101010101010101
0101010102010101010103010301010102010101020101010101010201010101020202020202010301010101010101010101010101010102030101010101020101010101010101020202020202030303030302030101010132010101010101020103010101010101010102020202020202020202010101010101010101010101
0101010102030101010302010201020101010103020202010101010101010102020101010101020301010101010101030302010201010102020201010103020101010101010101010102020202020202020202020202020202020202020202020202020202020201010101020202020202020202010101010101010101010101
0101010102020103010202020201020102010303050102010101010101010102010101010101020202020101010102020202010201010101050101010302020101010101010101010101010202020202020202020202020202020202020202020202020202020202010101010202020202020202010101010101010101010101
0101010101020202020202020202020102020202020101010101010101010101010101010101010501010101010301010101010201010102020202020202010101010101010101010101010101020202020202020202020202020202020202020202020202020202020101010102020202020202010101010101010101010101
0101010101010202020202020202020202020202020101010103010102020201020202010202020203010101010301010101010101010102020202020101010101010101010101010101010101010101020202020202020202020202020202020202020202020202020201010101020202020202010101010101010101010101
0101010101010102020202020202020202020202020202020202030101010101010101010101010202020202020201010101010102020202020201010101010101010101010101010101010101010101020202020202020202020202020202020202020202020202020202010101010202020202010101010101010101010101
