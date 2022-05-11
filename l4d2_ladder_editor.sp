#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define MAX_STR_LEN             100
#define DEFAULT_STEP_SIZE       1.0
#define TEAM_INFECTED           3
#define HUD_DRAW_INTERVAL       0.5

static selectedLadder[MAXPLAYERS + 1];
static bEditMode[MAXPLAYERS + 1];
static Float:stepSize[MAXPLAYERS + 1];
new Handle:hLadders;
new bool:in_attack[MAXPLAYERS + 1];
new bool:in_attack2[MAXPLAYERS + 1];
new bool:in_score[MAXPLAYERS + 1];
new bool:in_speed[MAXPLAYERS + 1];
new bool:bHudActive[MAXPLAYERS + 1];
new bool:bHudHintShown[MAXPLAYERS + 1];

public Plugin:myinfo = {
    name = "L4D2 Ladder Editor",
    author = "devilesk",
    version = "0.5.0",
    description = "Clone and move special infected ladders.",
    url = "https://github.com/devilesk/rl4d2l-plugins"
};

public OnPluginStart() {
    RegConsoleCmd("sm_edit", Command_Edit);
    RegConsoleCmd("sm_step", Command_Step);
    RegConsoleCmd("sm_select", Command_Select);
    RegConsoleCmd("sm_clone", Command_Clone);
    RegConsoleCmd("sm_move", Command_Move);
    RegConsoleCmd("sm_nudge", Command_Nudge);
    RegConsoleCmd("sm_rotate", Command_Rotate);
    RegConsoleCmd("sm_kill", Command_Kill);
    RegConsoleCmd("sm_info", Command_Info);
    RegConsoleCmd("sm_togglehud", Command_ToggleHud);
    HookEvent("player_team", PlayerTeam_Event);
    hLadders = CreateTrie();
    for (new i = 1; i <= MaxClients; i++) {
        selectedLadder[i] = -1;
        bEditMode[i] = false;
        in_attack[i] = false;
        in_attack2[i] = false;
        in_score[i] = false;
        in_speed[i] = false;
        bHudActive[i] = false;
        stepSize[i] = DEFAULT_STEP_SIZE;
    }
    CreateTimer(HUD_DRAW_INTERVAL, HudDrawTimer, _, TIMER_REPEAT);
}

public OnMapStart() {
    for (new i = 1; i <= MaxClients; i++) {
        selectedLadder[i] = -1;
        bEditMode[i] = false;
        in_attack[i] = false;
        in_attack2[i] = false;
        in_score[i] = false;
        in_speed[i] = false;
        bHudActive[i] = false;
        stepSize[i] = DEFAULT_STEP_SIZE;
    }
    ClearTrie(hLadders);
}

public OnClientAuthorized(client, const String:auth[])
{
    bHudHintShown[client] = false;
}

public OnClientDisconnect_Post(client)
{
    bEditMode[client] = false;
    in_attack[client] = false;
    in_attack2[client] = false;
    in_score[client] = false;
    in_speed[client] = false;
    bHudActive[client] = false;
    stepSize[client] = DEFAULT_STEP_SIZE;
}

stock SetClientFrozen(client, freeze)
{
    SetEntityMoveType(client, freeze ? MOVETYPE_NONE : MOVETYPE_WALK);
}

public Action:Command_ToggleHud(client, args) 
{
    bHudActive[client] = !bHudActive[client];
    PrintToChat(client, "<HUD>梯子实体编辑HUD", (bHudActive[client] ? "开启" : "关闭"));
}

public Action:HudDrawTimer(Handle:hTimer) 
{
    

    for (new i = 1; i <= MaxClients; i++) 
    {
        if (!bHudActive[i] || IsFakeClient(i))
            continue;
        new Handle:hud = CreatePanel();
        FillHudInfo(i, hud);
        SendPanelToClient(hud, i, DummyHudHandler, 3);
        CloseHandle(hud);
        if (!bHudHintShown[i])
        {
            bHudHintShown[i] = true;
            PrintToChat(i, "<HUD> 在聊天框输入!togglehud来切换梯子实体编辑HUD");
        }
    }
}

public DummyHudHandler(Handle:hMenu, MenuAction:action, param1, param2) {}

public FillHudInfo(client, Handle:hHud)
{
    DrawPanelText(hHud, "Ladder Editor HUD");
    DrawPanelText(hHud, " ");
    decl String:buffer[512];
    Format(buffer, sizeof(buffer), "Edit mode: %s", (bEditMode[client] ? "on" : "off"));
    DrawPanelText(hHud, buffer);
    DrawPanelText(hHud, " ");
    new entity = selectedLadder[client];
    if (!IsValidEntity(entity)) {
        Format(buffer, sizeof(buffer), "No ladder selected.");
        DrawPanelText(hHud, buffer);
        return;
    }

    decl String:modelname[128], Float:origin[3], Float:position[3], Float:normal[3], Float:angles[3];
    GetLadderEntityInfo(entity, modelname, sizeof(modelname), origin, position, normal, angles);

    Format(buffer, sizeof(buffer), "Entity: %i", entity);
    DrawPanelText(hHud, buffer);
    Format(buffer, sizeof(buffer), "Model Name: %s", modelname);
    DrawPanelText(hHud, buffer);
    Format(buffer, sizeof(buffer), "Position: %.2f, %.2f, %.2f", position[0], position[1], position[2]);
    DrawPanelText(hHud, buffer);
    Format(buffer, sizeof(buffer), "Origin: %.2f, %.2f, %.2f", origin[0], origin[1], origin[2]);
    DrawPanelText(hHud, buffer);
    Format(buffer, sizeof(buffer), "Normal: %.2f, %.2f, %.2f", normal[0], normal[1], normal[2]);
    DrawPanelText(hHud, buffer);
    Format(buffer, sizeof(buffer), "Angles: %.2f, %.2f, %.2f", angles[0], angles[1], angles[2]);
    DrawPanelText(hHud, buffer);
}

public bool:GetEndPosition(client, Float:end[3])
{
    decl Float:start[3], Float:angle[3];
    GetClientEyePosition(client, start);
    GetClientEyeAngles(client, angle);
    TR_TraceRayFilter(start, angle, MASK_SOLID, RayType_Infinite, TraceEntityFilterPlayer, client);
    if (TR_DidHit(INVALID_HANDLE))
    {
        TR_GetEndPosition(end, INVALID_HANDLE);
        return true;
    }
    return false;
}

public bool:TraceEntityFilterPlayer(entity, contentsMask, any:data)
{
    return entity > MaxClients;
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon) {
    if (client <= 0 || client > MaxClients) return Plugin_Continue;
    if (!IsClientInGame(client)) return Plugin_Continue;
    if (IsFakeClient(client)) return Plugin_Continue;
    
    new prevButtons = buttons;

    // Player was holding m1, and now isn't. (Released)
    if (buttons & IN_ATTACK != IN_ATTACK && in_attack[client]) {
        in_attack[client] = false;
        if (bEditMode[client])
            Command_Select(client, 0);
    }
    // Player was not holding m1, and now is. (Pressed)
    if (buttons & IN_ATTACK == IN_ATTACK && !in_attack[client]) {
        in_attack[client] = true;
    }

    // Player was holding m2, and now isn't. (Released)
    if (buttons & IN_ATTACK2 != IN_ATTACK2 && in_attack2[client]) {
        in_attack2[client] = false;
        if (bEditMode[client]) {
            decl Float:end[3];
            if (GetEndPosition(client, end))
                Move(client, end[0], end[1], end[2], true);
            else
                PrintToChat(client, "无效的终端位置");
        }
    }
    // Player was not holding m2, and now is. (Pressed)
    if (buttons & IN_ATTACK2 == IN_ATTACK2 && !in_attack2[client]) {
        in_attack2[client] = true;
    }

    // Player was holding tab, and now isn't. (Released)
    if (buttons & IN_SCORE != IN_SCORE && in_score[client]) {
        in_score[client] = false;
        Command_Edit(client, 0);
    }
    // Player was not holding tab, and now is. (Pressed)
    if (buttons & IN_SCORE == IN_SCORE && !in_score[client]) {
        in_score[client] = true;
    }

    // Player was holding shift, and now isn't. (Released)
    if (buttons & IN_SPEED != IN_SPEED && in_speed[client]) {
        in_speed[client] = false;
        if (bEditMode[client])
            RotateStep(client);
    }
    // Player was not holding shift, and now is. (Pressed)
    if (buttons & IN_SPEED == IN_SPEED && !in_speed[client]) {
        in_speed[client] = true;
    }
    
    if (!bEditMode[client]) return Plugin_Continue;

    if (buttons & IN_MOVELEFT == IN_MOVELEFT) {
        Nudge(client, -stepSize[client], 0.0, 0.0, false);
    }
    if (buttons & IN_MOVERIGHT == IN_MOVERIGHT) {
        Nudge(client, stepSize[client], 0.0, 0.0, false);
    }
    if (buttons & IN_FORWARD == IN_FORWARD) {
        Nudge(client, 0.0, stepSize[client], 0.0, false);
    }
    if (buttons & IN_BACK == IN_BACK) {
        Nudge(client, 0.0, -stepSize[client], 0.0, false);
    }
    if (buttons & IN_USE == IN_USE) {
        Nudge(client, 0.0, 0.0, stepSize[client], false);
    }
    if (buttons & IN_RELOAD == IN_RELOAD) {
        Nudge(client, 0.0, 0.0, -stepSize[client], false);
    }

    buttons &= ~(IN_ATTACK | IN_ATTACK2 | IN_SCORE | IN_USE | IN_RELOAD);

    if (prevButtons != buttons) {
        return Plugin_Changed;
    }
    return Plugin_Continue;
}

public PlayerTeam_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    new team = GetEventInt(event, "team");
    if (team != TEAM_INFECTED && bEditMode[client]) {
        bEditMode[client] = false;
        PrintToChat(client, "退出编辑模式");
    }
}

public Action Command_Step(int client, int args)
{
    if (args != 1) {
        PrintToChat(client, "[SM] Usage: sm_step <size>");
        return Plugin_Handled;
    }
    char x[8];
    GetCmdArg(1, x, sizeof(x));
    new size = StringToInt(x);
    if (size > 0) {
        stepSize[client] = size * 1.0;
        PrintToChat(client, "Step size set to（步长设置为） %i.", size);
    }
    else {
        PrintToChat(client, "Step size must be greater than（歩长必须大于） 0.");
    }
    return Plugin_Handled;
}

public Action Command_Edit(int client, int args)
{
    if (GetClientTeam(client) != TEAM_INFECTED) {
        PrintToChat(client, "必须在感染者团队中才能进入编辑模式");
        return Plugin_Handled;
    }
    if (bEditMode[client]) {
        bEditMode[client] = false;
        SetClientFrozen(client, false);
        PrintToChat(client, "退出编辑模式");
    }
    else {
        bEditMode[client] = true;
        SetClientFrozen(client, true);
        PrintToChat(client, "进入编辑模式");
    }
    return Plugin_Handled;
}

public Action Command_Kill(int client, int args)
{
    decl String:modelname[128];
    new String:classname[MAX_STR_LEN];
    new entity = selectedLadder[client];
    if (IsValidEntity(entity)) {
        GetEntityClassname(entity, classname, MAX_STR_LEN);
        new Float:normal[3];
        new Float:origin[3];
        new Float:position[3];
        decl Float:mins[3], Float:maxs[3];
        GetEntPropVector(entity, Prop_Send, "m_climbableNormal", normal);
        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
        GetEntPropVector(entity,Prop_Send,"m_vecMins",mins);
        GetEntPropVector(entity,Prop_Send,"m_vecMaxs",maxs);
        position[0] = origin[0] + (mins[0] + maxs[0]) * 0.5;
        position[1] = origin[1] + (mins[1] + maxs[1]) * 0.5;
        position[2] = origin[1] + (mins[2] + maxs[2]) * 0.5;
        AcceptEntityInput(entity, "Kill");
        selectedLadder[client] = -1;
        decl String:key[8];
        IntToString(entity, key, 8);
        RemoveFromTrie(hLadders, key);
        PrintToChat(client, "在 %i, %s at (%.2f,%.2f,%.2f). 位置: (%.2f,%.2f,%.2f). 法线: (%.2f,%.2f,%.2f) 删除梯子实体实体", entity, modelname, position[0], position[1], position[2], origin[0], origin[1], origin[2], normal[0], normal[1], normal[2]);
    }
    else {
        PrintToChat(client, "没有选择梯子实体.");
    }
    return Plugin_Handled;
}

public GetLadderEntityInfo(entity, String:modelname[], modelnamelen, Float:origin[3], Float:position[3], Float:normal[3], Float:angles[3]) {
    decl Float:mins[3], Float:maxs[3];
    GetEntPropString(entity, Prop_Data, "m_ModelName", modelname, modelnamelen);
    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
    GetEntPropVector(entity, Prop_Send, "m_vecMins", mins);
    GetEntPropVector(entity, Prop_Send, "m_vecMaxs", maxs);
    GetEntPropVector(entity, Prop_Send, "m_climbableNormal", normal);
    GetEntPropVector(entity, Prop_Send, "m_angRotation", angles);
    Math_RotateVector(mins, angles, mins);
    Math_RotateVector(maxs, angles, maxs);
    position[0] = origin[0] + (mins[0] + maxs[0]) * 0.5;
    position[1] = origin[1] + (mins[1] + maxs[1]) * 0.5;
    position[2] = origin[2] + (mins[2] + maxs[2]) * 0.5;
}

public Action Command_Info(int client, int args)
{
    new String:classname[MAX_STR_LEN];
    new entity = GetClientAimTarget(client, false);
    if (IsValidEntity(entity)) {
        GetEntityClassname(entity, classname, MAX_STR_LEN);
        if (StrEqual(classname, "func_simpleladder", false)) {
            decl String:modelname[128], Float:origin[3], Float:position[3], Float:normal[3], Float:angles[3];
            GetLadderEntityInfo(entity, modelname, sizeof(modelname), origin, position, normal, angles);

            PrintToChat(client, "梯子实体%i, %在(%.2f,%.2f,%.2f). 位置: (%.2f,%.2f,%.2f). 法线: (%.2f,%.2f,%.2f). 角度: (%.2f,%.2f,%.2f)", entity, modelname, position[0], position[1], position[2], origin[0], origin[1], origin[2], normal[0], normal[1], normal[2], angles[0], angles[1], angles[2]);

            PrintToConsole(client, "add:");
            PrintToConsole(client, "{");
            PrintToConsole(client, "    \"model\" \"%s\"", modelname);
            PrintToConsole(client, "    \"normal.z\" \"%.2f\"", normal[2]);
            PrintToConsole(client, "    \"normal.y\" \"%.2f\"", normal[1]);
            PrintToConsole(client, "    \"normal.x\" \"%.2f\"", normal[0]);
            PrintToConsole(client, "    \"team\" \"2\"");
            PrintToConsole(client, "    \"classname\" \"func_simpleladder\"");
            PrintToConsole(client, "    \"origin\" \"%.2f %.2f %.2f\"", origin[0], origin[1], origin[2]);
            PrintToConsole(client, "    \"angles\" \"%.2f %.2f %.2f\"", angles[0], angles[1], angles[2]);
            PrintToConsole(client, "}");
        }
        else {
            PrintToChat(client, "Not looking at a ladder（没有查看梯子实体）. 实体 %i, 类名: %s", entity, classname);
        }
    }
    else {
        PrintToChat(client, "查看无效实体 %i", entity);
    }
    return Plugin_Handled;
}

public RotateStep(int client)
{
    new entity = selectedLadder[client];
    if (IsValidEntity(entity)) {
        decl String:modelname[128], Float:origin[3], Float:position[3], Float:normal[3], Float:angles[3];
        GetLadderEntityInfo(entity, modelname, sizeof(modelname), origin, position, normal, angles);
        Rotate(client, 0.0, angles[1] + 90, 0.0, true);
    }
    else {
        PrintToChat(client, "没有选择梯子实体");
    }
}

public Nudge(int client, float x, float y, float z, bool bPrint)
{
    new entity = selectedLadder[client];
    if (IsValidEntity(entity)) {
        new Float:position[3];
        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);
        new Float:origin[3];
        origin[0] = position[0] + x;
        origin[1] = position[1] + y;
        origin[2] = position[2] + z;
        TeleportEntity(entity, origin, NULL_VECTOR, NULL_VECTOR);
        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);
        if (bPrint)
            PrintToChat(client, "移动梯子实体实体 %i. 位置 (%.2f,%.2f,%.2f)", entity, origin[0], origin[1], origin[2]);
    }
    else {
        if (bPrint)
            PrintToChat(client, "没有选择梯子实体");
    }
}

public Rotate(int client, float x, float y, float z, bool bPrint)
{
    new entity = selectedLadder[client];
    if (IsValidEntity(entity)) {
        new sourceEnt;
        decl String:key[8];
        IntToString(entity, key, 8);
        if (!GetTrieValue(hLadders, key, sourceEnt)) {
            if (bPrint)
                PrintToChat(client, "未找到原始梯子实体");
            return;
        }
        
        decl String:modelname[128], Float:sourceOrigin[3], Float:sourcePos[3], Float:sourceNormal[3], Float:sourceAngles[3];
        GetLadderEntityInfo(sourceEnt, modelname, sizeof(modelname), sourceOrigin, sourcePos, sourceNormal, sourceAngles);
        if (bPrint)
            PrintToChat(client, "原始梯子实体 %i 在 (%.2f,%.2f,%.2f)", sourceEnt, sourcePos[0], sourcePos[1], sourcePos[2]);
        
        decl Float:origin[3], Float:position[3], Float:normal[3], Float:angles[3];
        GetLadderEntityInfo(entity, modelname, sizeof(modelname), origin, position, normal, angles);
        
        angles[0] = x;
        angles[1] = y;
        angles[2] = z;
        
        new Float:rotatedPos[3];
        Math_RotateVector(sourcePos, angles, rotatedPos);
        
        origin[0] = -rotatedPos[0] + position[0];
        origin[1] = -rotatedPos[1] + position[1];
        origin[2] = -rotatedPos[2] + position[2];
    
        TeleportEntity(entity, origin, angles, NULL_VECTOR);
        
        Math_RotateVector(sourceNormal, angles, normal);
        SetEntPropVector(entity, Prop_Send, "m_climbableNormal", normal);
        
        if (bPrint)
            PrintToChat(client, "旋转梯子实体 %i. 位置 (%.2f,%.2f,%.2f). 角度 (%.2f,%.2f,%.2f). 法线 (%.2f,%.2f,%.2f)", entity, origin[0], origin[1], origin[2], angles[0], angles[1], angles[2], normal[0], normal[1], normal[2]);
    }
    else {
        if (bPrint)
            PrintToChat(client, "没有选择梯子实体");
    }
}

public Move(int client, float x, float y, float z, bool bPrint)
{
    new entity = selectedLadder[client];
    if (IsValidEntity(entity)) {
        new sourceEnt;
        decl String:key[8];
        IntToString(entity, key, 8);
        if (!GetTrieValue(hLadders, key, sourceEnt)) {
            if (bPrint)
                PrintToChat(client, "未找到原始梯子实体");
            return;
        }
        
        decl String:modelname[128], Float:origin[3], Float:sourcePos[3], Float:normal[3], Float:angles[3];
        GetLadderEntityInfo(sourceEnt, modelname, sizeof(modelname), origin, sourcePos, normal, angles);

        if (bPrint)
            PrintToChat(client, "原始梯子实体 %i 在 (%.2f,%.2f,%.2f)", sourceEnt, sourcePos[0], sourcePos[1], sourcePos[2]);
        
        origin[0] = x - sourcePos[0];
        origin[1] = y - sourcePos[1];
        origin[2] = z - sourcePos[2];
    
        TeleportEntity(entity, origin, NULL_VECTOR, NULL_VECTOR);
        if (bPrint)
            PrintToChat(client, "移动梯子实体实体 %i. 位置 (%.2f,%.2f,%.2f)", entity, origin[0], origin[1], origin[2]);
    }
    else {
        if (bPrint)
            PrintToChat(client, "没有选择梯子实体.");
    }
}

public Action Command_Rotate(int client, int args)
{
    if (args != 3) {
        PrintToChat(client, "[SM] Usage: sm_rotate <x> <y> <z>");
        return Plugin_Handled;
    }
    char x[8], y[8], z[8];
    GetCmdArg(1, x, sizeof(x));
    GetCmdArg(2, y, sizeof(y));
    GetCmdArg(3, z, sizeof(z));
    Rotate(client, StringToFloat(x), StringToFloat(y), StringToFloat(z), true);
    return Plugin_Handled;
}

public Action Command_Nudge(int client, int args)
{
    if (args != 3) {
        PrintToChat(client, "[SM] Usage: sm_nudge <x> <y> <z>");
        return Plugin_Handled;
    }
    char x[8], y[8], z[8];
    GetCmdArg(1, x, sizeof(x));
    GetCmdArg(2, y, sizeof(y));
    GetCmdArg(3, z, sizeof(z));
    Nudge(client, StringToFloat(x), StringToFloat(y), StringToFloat(z), true);
    return Plugin_Handled;
}

public Action Command_Move(int client, int args)
{
    if (args != 3) {
        PrintToChat(client, "[SM] Usage: sm_move <x> <y> <z>");
        return Plugin_Handled;
    }
    char x[8], y[8], z[8];
    GetCmdArg(1, x, sizeof(x));
    GetCmdArg(2, y, sizeof(y));
    GetCmdArg(3, z, sizeof(z));
    Move(client, StringToFloat(x), StringToFloat(y), StringToFloat(z), true);
    return Plugin_Handled;
}

public Action Command_Clone(int client, int args)
{
    new String:classname[MAX_STR_LEN];
    new sourceEnt = selectedLadder[client];
    if (IsValidEntity(sourceEnt)) {
        GetEntityClassname(sourceEnt, classname, MAX_STR_LEN);
        if (!StrEqual(classname, "func_simpleladder", false)) {
            selectedLadder[client] = -1;
            PrintToChat(client, "没有选择梯子实体");
            return Plugin_Handled;
        }
        decl String:modelname[128], Float:origin[3], Float:position[3], Float:normal[3], Float:angles[3];
        GetLadderEntityInfo(sourceEnt, modelname, sizeof(modelname), origin, position, normal, angles);
        PrecacheModel(modelname, true);
        new entity = CreateEntityByName("func_simpleladder");
        if (entity == -1)
        {
            PrintToChat(client, "创建梯子实体失败");
            return Plugin_Handled;
        }
        decl String:buf[32];
        DispatchKeyValue(entity, "model", modelname);
        Format(buf, sizeof(buf), "%.6f", normal[2]);
        DispatchKeyValue(entity, "normal.z", buf);
        Format(buf, sizeof(buf), "%.6f", normal[1]);
        DispatchKeyValue(entity, "normal.y", buf);
        Format(buf, sizeof(buf), "%.6f", normal[0]);
        DispatchKeyValue(entity, "normal.x", buf);
        DispatchKeyValue(entity, "team", "2");
        DispatchKeyValue(entity, "origin", "50 0 0");

        DispatchSpawn(entity);
        selectedLadder[client] = entity;
        decl String:key[8];
        IntToString(entity, key, 8);
        SetTrieValue(hLadders, key, sourceEnt, true);
        PrintToChat(client, "克隆梯子实体 %i. 新实体 %i", sourceEnt, entity);
    }
    else {
        PrintToChat(client, "没有选择梯子实体");
    }
    return Plugin_Handled;
}

public Action Command_Select(int client, int args)
{
    new String:classname[MAX_STR_LEN];
    new entity = GetClientAimTarget(client, false);
    if (IsValidEntity(entity)) {
        GetEntityClassname(entity, classname, MAX_STR_LEN);
        if (StrEqual(classname, "func_simpleladder", false)) {
            selectedLadder[client] = entity;
            
            decl String:modelname[128], Float:origin[3], Float:position[3], Float:normal[3], Float:angles[3];
            GetLadderEntityInfo(entity, modelname, sizeof(modelname), origin, position, normal, angles);
            PrintToChat(client, "选择梯子实体 %i, %s 在 (%.2f,%.2f,%.2f). 位置: (%.2f,%.2f,%.2f). 法线: (%.2f,%.2f,%.2f)", entity, modelname, position[0], position[1], position[2], origin[0], origin[1], origin[2], normal[0], normal[1], normal[2]);
        }
        else {
            selectedLadder[client] = -1;
            PrintToChat(client, "Not looking at a ladder（没有查看梯子实体） 实体 %i, 类名: %s", entity, classname);
        }
    }
    else {
        selectedLadder[client] = -1;
        PrintToChat(client, "查看无效实体 %i", entity);
    }
    return Plugin_Handled;
}

// from smlib https://github.com/bcserv/smlib

/**
 * Rotates a vector around its zero-point.
 * Note: As example you can rotate mins and maxs of an entity and then add its origin to mins and maxs to get its bounding box in relation to the world and its rotation.
 * When used with players use the following angle input:
 *   angles[0] = 0.0;
 *   angles[1] = 0.0;
 *   angles[2] = playerEyeAngles[1];
 *
 * @param vec 			Vector to rotate.
 * @param angles 		How to rotate the vector.
 * @param result		Output vector.
 * @noreturn
 */
stock Math_RotateVector(const Float:vec[3], const Float:angles[3], Float:result[3])
{
    // First the angle/radiant calculations
    decl Float:rad[3];
    // I don't really know why, but the alpha, beta, gamma order of the angles are messed up...
    // 2 = xAxis
    // 0 = yAxis
    // 1 = zAxis
    rad[0] = DegToRad(angles[2]);
    rad[1] = DegToRad(angles[0]);
    rad[2] = DegToRad(angles[1]);

    // Pre-calc function calls
    new Float:cosAlpha = Cosine(rad[0]);
    new Float:sinAlpha = Sine(rad[0]);
    new Float:cosBeta = Cosine(rad[1]);
    new Float:sinBeta = Sine(rad[1]);
    new Float:cosGamma = Cosine(rad[2]);
    new Float:sinGamma = Sine(rad[2]);

    // 3D rotation matrix for more information: http://en.wikipedia.org/wiki/Rotation_matrix#In_three_dimensions
    new Float:x = vec[0], Float:y = vec[1], Float:z = vec[2];
    new Float:newX, Float:newY, Float:newZ;
    newY = cosAlpha*y - sinAlpha*z;
    newZ = cosAlpha*z + sinAlpha*y;
    y = newY;
    z = newZ;

    newX = cosBeta*x + sinBeta*z;
    newZ = cosBeta*z - sinBeta*x;
    x = newX;
    z = newZ;

    newX = cosGamma*x - sinGamma*y;
    newY = cosGamma*y + sinGamma*x;
    x = newX;
    y = newY;

    // Store everything...
    result[0] = x;
    result[1] = y;
    result[2] = z;
}