unit KM_PlayerStats;
{$I KaM_Remake.inc}
interface
uses Classes, KM_Defaults, KM_CommonTypes;

{These are mission specific settings and stats for each player}
type
  TKMPlayerStats = class
  private
    Houses:array[1..HOUSE_COUNT]of record
      Initial,      //created by script on mission start
      Built,        //constructed by player
      SelfDestruct, //deconstructed by player
      Lost,         //lost from attacks and self-demolished
      Destroyed:word; //damage to other players
    end;
    Units:array[1..40]of record
      Initial,
      Trained,
      Lost,
      Killed:word;
    end;
    ResourceRatios:array[1..4,1..4]of byte;
  public
    AllowToBuild:array[1..HOUSE_COUNT]of boolean; //Allowance derived from mission script
    BuildReqDone:array[1..HOUSE_COUNT]of boolean; //If building requirements performed or assigned from script
    constructor Create;
    procedure HouseCreated(aType:THouseType; aWasBuilt:boolean);
    procedure HouseLost(aType:THouseType);
    procedure HouseSelfDestruct(aType:THouseType);
    procedure HouseDestroyed(aType:THouseType);

    procedure UnitCreated(aType:TUnitType; aWasTrained:boolean);
    procedure UnitLost(aType:TUnitType);
    procedure UnitKilled(aType:TUnitType);

    procedure UpdateReqDone(aType:THouseType);

    function GetHouseQty(aType:THouseType):integer;
    function GetUnitQty(aType:TUnitType):integer;
    function GetArmyCount:integer;
    function GetCanBuild(aType:THouseType):boolean;

    function GetRatio(aRes:TResourceType; aHouse:THouseType):byte;
    procedure SetRatio(aRes:TResourceType; aHouse:THouseType; aValue:byte);

    function GetUnitsLost:cardinal;
    function GetUnitsKilled:cardinal;
    function GetHousesLost:cardinal;
    function GetHousesDestroyed:cardinal;
    function GetHousesBuilt:cardinal;
    function GetUnitsTrained:cardinal;
    function GetWeaponsProduced:cardinal;
    function GetSoldiersTrained:cardinal;

    procedure Save(SaveStream:TKMemoryStream);
    procedure Load(LoadStream:TKMemoryStream);
  end;


implementation


{ TKMPlayerStats }
constructor TKMPlayerStats.Create;
var i,k:integer;
begin
  Inherited;
  for i:=1 to length(AllowToBuild) do
    AllowToBuild[i] := true;

  BuildReqDone[byte(ht_Store)] := true;

  for i:=1 to 4 do for k:=1 to 4 do
    ResourceRatios[i,k] := DistributionDefaults[i,k];
end;


procedure TKMPlayerStats.UpdateReqDone(aType:THouseType);
var i:integer;
begin
  for i:=1 to length(BuildingAllowed[1]) do
    if BuildingAllowed[byte(aType),i]<>ht_None then
      BuildReqDone[byte(BuildingAllowed[byte(aType),i])]:=true;
end;


procedure TKMPlayerStats.HouseCreated(aType:THouseType; aWasBuilt:boolean);
begin
  if aWasBuilt then
    inc(Houses[byte(aType)].Built)
  else
    inc(Houses[byte(aType)].Initial);
  UpdateReqDone(aType);
end;


procedure TKMPlayerStats.HouseLost(aType:THouseType);
begin
  inc(Houses[byte(aType)].Lost);
end;


procedure TKMPlayerStats.HouseSelfDestruct(aType:THouseType);
begin
  inc(Houses[byte(aType)].SelfDestruct);
end;


procedure TKMPlayerStats.HouseDestroyed(aType:THouseType);
begin
  inc(Houses[byte(aType)].Destroyed);
end;


procedure TKMPlayerStats.UnitCreated(aType:TUnitType; aWasTrained:boolean);
begin
  if aWasTrained then
    inc(Units[byte(aType)].Trained)
  else
    inc(Units[byte(aType)].Initial);
end;


procedure TKMPlayerStats.UnitLost(aType:TUnitType);
begin
  inc(Units[byte(aType)].Lost);
end;


procedure TKMPlayerStats.UnitKilled(aType:TUnitType);
begin
  inc(Units[byte(aType)].Killed);
end;


function TKMPlayerStats.GetHouseQty(aType:THouseType):integer;
var i:integer;
begin
  if aType <> ht_None then
    Result := Houses[byte(aType)].Initial + Houses[byte(aType)].Built - Houses[byte(aType)].SelfDestruct - Houses[byte(aType)].Lost
  else begin
    Result := 0;
    for i:=1 to HOUSE_COUNT do
      inc(Result, Houses[i].Initial + Houses[i].Built - Houses[i].SelfDestruct - Houses[i].Lost);
  end;
end;


function TKMPlayerStats.GetUnitQty(aType:TUnitType):integer;
var i:integer;
begin
  Result := Units[byte(aType)].Initial + Units[byte(aType)].Trained - Units[byte(aType)].Lost;
  if aType = ut_Recruit then
    for i:= byte(ut_Militia) to byte(ut_Barbarian) do
      dec(Result,Units[i].Trained); //Trained soldiers use a recruit
end;


function TKMPlayerStats.GetArmyCount:integer;
var ut:TUnitType;
begin
  Result := 0;
  for ut:=ut_Militia to ut_Barbarian do
    Result := Result + GetUnitQty(ut);
end;


function TKMPlayerStats.GetCanBuild(aType:THouseType):boolean;
begin
  Result := BuildReqDone[byte(aType)] AND AllowToBuild[byte(aType)];
end;


function TKMPlayerStats.GetRatio(aRes:TResourceType; aHouse:THouseType):byte;
begin
  Result:=5; //Default should be 5, for house/resource combinations that don't have a setting (on a side note this should be the only place the resourse limit is defined)
  case aRes of
    rt_Steel: if aHouse=ht_WeaponSmithy   then Result:=ResourceRatios[1,1] else
              if aHouse=ht_ArmorSmithy    then Result:=ResourceRatios[1,2];
    rt_Coal:  if aHouse=ht_IronSmithy     then Result:=ResourceRatios[2,1] else
              if aHouse=ht_Metallurgists  then Result:=ResourceRatios[2,2] else
              if aHouse=ht_WeaponSmithy   then Result:=ResourceRatios[2,3] else
              if aHouse=ht_ArmorSmithy    then Result:=ResourceRatios[2,4];
    rt_Wood:  if aHouse=ht_ArmorWorkshop  then Result:=ResourceRatios[3,1] else
              if aHouse=ht_WeaponWorkshop then Result:=ResourceRatios[3,2];
    rt_Corn:  if aHouse=ht_Mill           then Result:=ResourceRatios[4,1] else
              if aHouse=ht_Swine          then Result:=ResourceRatios[4,2] else
              if aHouse=ht_Stables        then Result:=ResourceRatios[4,3];
  end;
end;


procedure TKMPlayerStats.SetRatio(aRes:TResourceType; aHouse:THouseType; aValue:byte);
begin
  case aRes of
    rt_Steel: if aHouse=ht_WeaponSmithy   then ResourceRatios[1,1]:=aValue else
              if aHouse=ht_ArmorSmithy    then ResourceRatios[1,2]:=aValue;
    rt_Coal:  if aHouse=ht_IronSmithy     then ResourceRatios[2,1]:=aValue else
              if aHouse=ht_Metallurgists  then ResourceRatios[2,2]:=aValue else
              if aHouse=ht_WeaponSmithy   then ResourceRatios[2,3]:=aValue else
              if aHouse=ht_ArmorSmithy    then ResourceRatios[2,4]:=aValue;
    rt_Wood:  if aHouse=ht_ArmorWorkshop  then ResourceRatios[3,1]:=aValue else
              if aHouse=ht_WeaponWorkshop then ResourceRatios[3,2]:=aValue;
    rt_Corn:  if aHouse=ht_Mill           then ResourceRatios[4,1]:=aValue else
              if aHouse=ht_Swine          then ResourceRatios[4,2]:=aValue else
              if aHouse=ht_Stables        then ResourceRatios[4,3]:=aValue;
    else fLog.AssertToLog(false,'Unexpected resource at SetRatio');
  end;
end;


function TKMPlayerStats.GetUnitsLost:cardinal;
var i:integer;
begin
  Result:=0;
  for i:=low(Units) to high(Units) do
    inc(Result,Units[i].Lost);
end;


function TKMPlayerStats.GetUnitsKilled:cardinal;
var i:integer;
begin
  Result:=0;
  for i:=low(Units) to high(Units) do
    inc(Result,Units[i].Killed);
end;


function TKMPlayerStats.GetHousesLost:cardinal;
var i:integer;
begin
  Result:=0;
  for i:=low(Houses) to high(Houses) do
    inc(Result,Houses[i].Lost);
end;


function TKMPlayerStats.GetHousesDestroyed:cardinal;
var i:integer;
begin
  Result:=0;
  for i:=low(Houses) to high(Houses) do
    inc(Result,Houses[i].Destroyed);
end;


function TKMPlayerStats.GetHousesBuilt:cardinal;
var i:integer;
begin
  Result:=0;
  for i:=low(Houses) to high(Houses) do
    inc(Result,Houses[i].Built);
end;


//The value includes all citizens, Warriors are counted separately
function TKMPlayerStats.GetUnitsTrained:cardinal;
var i:integer;
begin
  Result:=0;
  for i:=byte(ut_Serf) to byte(ut_Recruit) do
    inc(Result,Units[i].Trained);
end;


function TKMPlayerStats.GetWeaponsProduced:cardinal;
begin
  Result:=0;
end;


//The value includes all Warriors
function TKMPlayerStats.GetSoldiersTrained:cardinal;
var i:integer;
begin
  Result:=0;
  for i:=byte(ut_Militia) to byte(ut_Barbarian) do
    inc(Result,Units[i].Trained);
end;


procedure TKMPlayerStats.Save(SaveStream:TKMemoryStream);
var i,k:integer;
begin
  for i:=1 to HOUSE_COUNT do SaveStream.Write(Houses[i].Initial);
  for i:=1 to HOUSE_COUNT do SaveStream.Write(Houses[i].Built);
  for i:=1 to HOUSE_COUNT do SaveStream.Write(Houses[i].Lost);
  for i:=1 to HOUSE_COUNT do SaveStream.Write(Houses[i].Destroyed);
  for i:=1 to 40 do SaveStream.Write(Units[i].Initial);
  for i:=1 to 40 do SaveStream.Write(Units[i].Trained);
  for i:=1 to 40 do SaveStream.Write(Units[i].Lost);
  for i:=1 to 40 do SaveStream.Write(Units[i].Killed);
  for i:=1 to 4 do for k:=1 to 4 do SaveStream.Write(ResourceRatios[i,k]);
  for i:=1 to HOUSE_COUNT do SaveStream.Write(AllowToBuild[i]);
  for i:=1 to HOUSE_COUNT do SaveStream.Write(BuildReqDone[i]);
end;


procedure TKMPlayerStats.Load(LoadStream:TKMemoryStream);
var i,k:integer;
begin
  for i:=1 to HOUSE_COUNT do LoadStream.Read(Houses[i].Initial);
  for i:=1 to HOUSE_COUNT do LoadStream.Read(Houses[i].Built);
  for i:=1 to HOUSE_COUNT do LoadStream.Read(Houses[i].Lost);
  for i:=1 to HOUSE_COUNT do LoadStream.Read(Houses[i].Destroyed);
  for i:=1 to 40 do LoadStream.Read(Units[i].Initial);
  for i:=1 to 40 do LoadStream.Read(Units[i].Trained);
  for i:=1 to 40 do LoadStream.Read(Units[i].Lost);
  for i:=1 to 40 do LoadStream.Read(Units[i].Killed);
  for i:=1 to 4 do for k:=1 to 4 do LoadStream.Read(ResourceRatios[i,k]);
  for i:=1 to HOUSE_COUNT do LoadStream.Read(AllowToBuild[i]);
  for i:=1 to HOUSE_COUNT do LoadStream.Read(BuildReqDone[i]);
end;


end.
