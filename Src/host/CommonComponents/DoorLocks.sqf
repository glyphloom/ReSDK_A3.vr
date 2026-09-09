// ======================================================
// Copyright (c) 2017-2026 the ReSDK_A3 project
// sdk.relicta.ru
// ======================================================

#include <..\engine.hpp>

// Both faces belong to the same item. Descriptor travels with the door chunk.
doorLock_clearVisuals = {
	params ["_door"];
	{deleteVehicle _x} foreach (_door getVariable ["doorLockMeshes",[]]);
	_door setVariable ["doorLockMeshes",[]];
	_door setVariable ["doorLockVisualData",[]];
};

// Keep replacement faces hidden too if a door is currently interpolating.
doorLock_setVisualsHidden = {
	params ["_door","_hidden"];
	_door setVariable ["doorLockVisualsHidden",_hidden];
	{_x hideObject _hidden} foreach (_door getVariable ["doorLockMeshes",[]]);
};

doorLock_updateVisuals = {
	params ["_door","_data"];
	if ((_door getVariable ["doorLockVisualData",[]]) isEqualTo _data) exitWith {
		_door getVariable ["doorLockMeshes",[]]
	};
	[_door] call doorLock_clearVisuals;
	_door setVariable ["doorLockVisualData",_data];
	if (count _data == 0) exitWith {[]};
	_data params ["_pointer","_model","_position","_selection","_depth","_yaw","_tilt"];
	private _meshes = [];
	{
		private _mesh = createMesh([_model arg [0 arg 0 arg 0] arg true]);
		private _offset = _position vectorAdd [sin _yaw * _depth * _x,cos _yaw * _depth * _x,0];
		_mesh attachTo [_door,_offset,_selection,true];
		private _angle = _yaw + ifcheck(_x == 1,0,180);
		_mesh setVectorDirAndUp [[sin _angle,cos _angle,0],[cos _angle * sin _tilt,-sin _angle * sin _tilt,cos _tilt]];
		_mesh setVariable ["ref",_pointer];
		_mesh setVariable ["doorLockOwner",_door];
		_mesh disableCollisionWith _door;
		_mesh hideObject (_door getVariable ["doorLockVisualsHidden",false]);
		_meshes pushBack _mesh;
	} foreach [1,-1];
	_door setVariable ["doorLockMeshes",_meshes];
	_meshes
};
