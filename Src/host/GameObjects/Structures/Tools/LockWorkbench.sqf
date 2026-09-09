// ======================================================
// Copyright (c) 2017-2026 the ReSDK_A3 project
// sdk.relicta.ru
// ======================================================
#include <..\..\..\engine.hpp>
#include <..\..\..\oop.hpp>
#include <..\..\..\struct.hpp>
#include <..\..\GameConstants.hpp>

class(LockWorkbench) extends(Workbench)
	var(name,"Слесарный верстак");
	getter_func(getCraftStation,"locks");
	// Model-local tabletop bounds; tune in ReEditor for workbench_01_f.
	var(tableBounds,[[-1.25 arg -0.43 arg 0.45] arg [1.25 arg 0.43 arg 0.85]]);
	var(craftJob,[]);
	var(handleCraftUpdate,-1);

	func(destructor)
	{
		objParams();
		callSelf(clearStationCraft);
	};

	func(getTableItems)
	{
		objParams();
		if !callSelf(isInWorld) exitWith {[]};
		private _mesh = callSelf(getBasicLoc);
		getSelf(tableBounds) params ["_min","_max"];
		private _items = ["Item",callSelf(getPos),2,true,true] call getGameObjectOnPosition;
		_items select {
			private _pos = _mesh worldToModel (callFunc(_x,getPos));
			callFunc(_x,isInWorld) && {
				(_pos select 0) >= (_min select 0) && {(_pos select 0) <= (_max select 0)} &&
				{(_pos select 1) >= (_min select 1)} && {(_pos select 1) <= (_max select 1)} &&
				{(_pos select 2) >= (_min select 2)} && {(_pos select 2) <= (_max select 2)}
			}
		}
	};

	func(startStationCraft)
	{
		objParams_2(_usr,_recipe);
		if !callSelf(isInWorld) exitWith {};
		if (callFuncParams(_usr,getDistanceTo,this) > 2) exitWith {};
		if (count getSelf(craftJob) > 0) exitWith {
			callFuncParams(_usr,localSay,"Верстак занят." arg "error");
		};
		if !(_recipe callp(canSeeRecipe,_usr arg this)) exitWith {};
		private _items = callSelf(getTableItems);
		private _keys = _items select {isTypeOf(_x,Key)};
		private _keyData = [];
		if (count _keys > 0) then {
			private _key = _keys select 0;
			_keyData = [array_copy(getVar(_key,keyOwner)),getVar(_key,name)];
		};
		if ((_keys findIf {!([getVar(_x,keyOwner),_keyData select 0] call key_sameAccess)}) != -1) exitWith {
			callFuncParams(_usr,localSay,"Уберите лишние ключи с разными типами доступа." arg "error");
		};
		private _components = (_recipe getv(components)) apply {_x callv(createIngredientTempValidator)};
		{
			private _item = _x;
			{
				if !(_x callv(isReadyIngredient)) then {
					if (_x callp(isValidIngredient,_item)) exitWith {
						_x callp(handleValidIngredient,_item);
					};
				};
			} foreach _components;
		} foreach _items;
		if ((_components findIf {!(_x callv(canCraftFromIngredient))}) != -1) exitWith {
			callFuncParams(_usr,localSay,"Разложите на столешнице все необходимые материалы и инструменты." arg "error");
		};
		private _duration = _usr call (_recipe getv(opt_craft_duration));
		setSelf(craftJob,[_usr arg _recipe arg _components arg _keyData arg getPosWorld getSelf(loc) arg vectorDir getSelf(loc) arg (tickTime + _duration)]);
		callFuncParams(_usr,startProgress,this arg "target.finishStationCraft" arg _duration arg INTERACT_PROGRESS_TYPE_FULL);
		callSelfParams(startUpdateMethod,"updateStationCraft" arg "handleCraftUpdate");
	};

	func(isStationCraftValid)
	{
		objParams();
		getSelf(craftJob) params ["_usr","_recipe","_components","_keyData","_pos","_dir"];
		if (isNullReference(_usr) || {!callSelf(isInWorld)}) exitWith {false};
		if (callFuncParams(_usr,getDistanceTo,this) > 2) exitWith {false};
		if (getPosWorld getSelf(loc) distance _pos > 0.02 || {vectorDir getSelf(loc) distance _dir > 0.01}) exitWith {false};
		if !(_recipe callp(canSeeRecipe,_usr arg this)) exitWith {false};
		private _items = callSelf(getTableItems);
		private _valid = true;
		{
			private _component = _x;
			{
				private _item = _x select 0;
				if (!(_item in _items) || {!(_component callp(isValidIngredient,_item))}) exitWith {_valid = false};
			} foreach (_component getv(_foundItems));
		} foreach _components;
		private _keys = _items select {isTypeOf(_x,Key)};
		if (count _keyData == 0) exitWith {_valid && {count _keys == 0}};
		_valid && {count _keys > 0} && {(_keys findIf {!([getVar(_x,keyOwner),_keyData select 0] call key_sameAccess)}) == -1}
	};

	func(clearStationCraft)
	{
		objParams();
		if (count getSelf(craftJob) > 0) then {
			private _usr = getSelf(craftJob) select 0;
			if (!isNullReference(_usr) && {equals(getVar(_usr,progressData) select 0,this)}) then {callFuncParams(_usr,stopProgress,true)};
		};
		setSelf(craftJob,[]);
		callSelfParams(stopUpdateMethod,"handleCraftUpdate");
	};

	func(updateStationCraft)
	{
		objParams();
		if (count getSelf(craftJob) == 0) exitWith {callSelf(clearStationCraft)};
		private _usr = getSelf(craftJob) select 0;
		private _active = !isNullReference(_usr) && {equals(getVar(_usr,progressData) select 0,this)};
		if (!_active || {!callSelf(isStationCraftValid)}) then {
			if (_active) then {callFuncParams(_usr,stopProgress,true)};
			callSelf(clearStationCraft);
		};
	};

	func(finishStationCraft)
	{
		objParams_1(_usr);
		if (count getSelf(craftJob) == 0) exitWith {};
		getSelf(craftJob) params ["_worker","_recipe","_components","_keyData","_pos","_dir","_end"];
		if (!equals(_worker,_usr) || {tickTime < _end}) exitWith {};
		if !callSelf(isStationCraftValid) exitWith {callSelf(clearStationCraft)};
		private _roll = refcreate(0);
		private _success = _recipe callp(checkCraftSkills,_usr arg _roll);
		private _metal = [];
		{
			if (_x getv(destroy)) then {_metal append ((_x getv(_foundItems)) apply {_x select 0})};
		} foreach _components;
		if (!_success) then {_metal resize 1};
		{delete(_x)} foreach _metal;
		if (_success) then {
			private _class = _recipe getv(result) getv(class);
			private _outPos = getSelf(loc) modelToWorld [0,0,0.55];
			if (_class == "Key") then {
				private _key = ["Key",_outPos] call createItemInWorld;
				setVar(_key,keyOwner,array_copy(_keyData select 0));
				setVar(_key,name,_keyData select 1);
			} else {
				[_class,_outPos,_keyData] call doorLock_createPair;
			};
			callFuncParams(_usr,meSay,"создаёт " + (_recipe getv(name)));
		} else {
			callFuncParams(_usr,localSay,"Не получилось. Железяки испорчены." arg "error");
		};
		callSelf(clearStationCraft);
	};
endclass
