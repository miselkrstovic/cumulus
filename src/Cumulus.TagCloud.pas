(*
		com.roytanck.wpcumulus.TagCloud
		Copyright 2009: Roy Tanck

		This file is part of WP-Cumulus.

    WP-Cumulus is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    WP-Cumulus is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with WP-Cumulus.  If not, see <http://www.gnu.org/licenses/>.
*)

unit Cumulus.TagCloud;

interface

uses XMLDoc, ExtCtrls, SysUtils, Classes, Controls, StdCtrls,
  RegularExpressions, Graphics, Contnrs, Menus, Math, FlashCompat, Cumulus.Tag,
  Xml.XMLIntf;

Type
  TCloudDisplayMode = (dmTags, dmCategories, dmBoth);

  TNavigateToURLEvent = procedure(Sender: TObject; Request: TURLRequest; const Target : String) of object;

	TTagCloud = class(TMovieClip)
  private
    InternalTimer: TTimer;
    _OnNavigateToURL: TNavigateToURLEvent;

		// Private vars
		radius: Number;
		mcList: TFlashArray;
		dtr: Number;
		d: Number;
		sa: Number;
		ca: Number;
		sb: Number;
		cb: Number;
		sc: Number;
		cc: Number;
		originx: Number;
		originy: Number;
		tcolor1: TColor;
		hicolor: TColor;
		tcolor2: TColor;
		tspeed: Number;
		distr: Boolean;
		lasta: Number;
		lastb: Number;
    holder: TMovieClip;
		active: Boolean;
		myXML: TXML;

    mode: TCloudDisplayMode;

    procedure AddCategories(Cats: String);
    procedure Init(O: TXML);
    procedure UpdateTags(Sender: TObject);
    procedure DepthSort();
    procedure PositionAll();
    procedure MenuItemSelectHandler(Sender : TObject);
    procedure MouseExitHandler(Sender: TObject);
    procedure MouseMoveHandler(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure ResizeHandler(Sender: TObject);
    procedure ResizeHolder();
    procedure SineCosine(a: Number; b: Number; c: Number);
    function GetNumberFromString(const s: String):Number;
    function GetColorFromGradient( perc:Integer ):TColor;
    function GetBackgroundColor: TColor;
    procedure SetBackgroundColor(const Value: TColor);
    function GetTransparentMode: Boolean;
    procedure SetTransparentMode(const Value: Boolean);
    procedure SetSpeed(const Value: Integer);
  public
    constructor Create(AOwner: TComponent); override;
    procedure Initialize(O: TXML);
    destructor Destroy; override;

    property OnNavigateToURL: TNavigateToURLEvent read _OnNavigateToURL write _OnNavigateToURL;

    property DisplayMode : TCloudDisplayMode read mode write mode;
    property TransparentMode : Boolean read GetTransparentMode write SetTransparentMode;
    property TagColor: TColor read tcolor1 write tcolor1 default $333333;
    property TagColor2: TColor read tcolor2 write tcolor2 default $995500;
    property HighColor: TColor read hicolor write hicolor default $000000;
    property BackgroundColor: TColor read GetBackgroundColor write SetBackgroundColor;
    property RotationSpeed: Integer write SetSpeed default 1;
    property EvenlyDistributedTags: Boolean read distr write distr;

  end;

implementation

uses Variants, Utils;

constructor TTagCloud.Create(AOwner: TComponent);
begin
  Inherited Create(AOwner);

  ParentBackground := False;
  ParentColor := False;

  BevelInner := bvNone;
  BevelOuter := bvNone;
  BevelKind := bkNone;

  InternalTimer := TTimer.Create(Self);
  InternalTimer.Interval := 100;
  InternalTimer.Enabled := false;
end;

procedure TTagCloud.AddCategories(Cats: String);
var
  cArray: TFlashArray;
  smallest: Number;
  largest: Number;
  pattern: RegExp;
  I: Integer;
  parts: TFlashArray;
  nr: Number;
  node: String;
  scalefactor: Number;
begin
  // Unescape leave spaces as '+', so we have to filter these out manually
  // URLDecode() does it much cleaner than unescape()
  cats := URLDecode(cats);
  // use the fact that WP outputs line breaks to split the string into bits
  cats := StringReplace(cats, '<br />', '‡', [rfReplaceAll]);
  cArray := TFlashArray(explode(Char('‡'), cats));
  // loop though them to find the smallest and largest 'tags'
  smallest := 9999;
  largest := 0;
  pattern := '/\d/g';
  for  i := 0 to (cArray.Count-1) do begin
    parts := cArray[i].split( '</a>' );
    // user regular extpressions to get rid of extra stuff
    nr := Number( parts[1].match(pattern).join('') );
    largest := Math.max( largest, nr );
    smallest := Math.min( smallest, nr );
  end;
  // how much must we scale the categories to match the tags?
  if ( smallest = largest ) then begin
    scalefactor := 7 / largest;
  end else begin
    scalefactor := 14 / largest;
  end;
  // loop through them again and add to XML
  for i := 0 to cArray.Count-1 do begin
    parts := cArray[i].split( '</a>' );
    nr := Number( parts[1].match(pattern).join('') );
    node := '<a style=\''' + ((nr*scalefactor)+8) + '\''' + parts[0].substr( parts[0].indexOf('<a')+2 ) + '</a>';
    myXML.appendChild( node );
  end;
end;

procedure TTagCloud.init(o: TXML);
var
  largest: Number;
  smallest: Number;
  nr: Number;
  nr2: Number;
  perc: Integer;
  mc: TTag;
  node: IXMLNode;
  node2: IXMLNode;
  I: integer;

  col: TColor;
  hicol: TColor;
begin
  // Set some vars
  radius := 150;
  dtr := System.PI/180;
  d := 300;
  SineCosine(0, 0, 0);
  mcList := TFlashArray.Create;
  active := False;
  lasta := 1;
  lastb := 1;

  // Create holder mc, center it
  holder := TMovieClip.CreateEx(Self, true);
  holder.Parent := Self;
  ResizeHolder();

  // Loop through them to find the smallest and largest 'tags'
  largest := 0;
  smallest := 9999;
  for i := 0 to o.DocumentElement.ChildNodes.Count-1 do begin
    node := o.DocumentElement.ChildNodes.Get(i);
    nr := getNumberFromString(node.Attributes['style']);
    largest := Math.max(largest, nr);
    smallest := Math.min(smallest, nr);
  end;

  // Create movie clips
  for i := 0 to o.DocumentElement.ChildNodes.Count-1 do begin
    node2 := o.DocumentElement.ChildNodes.Get(i);

    // Figure out what color it should be
    nr2 := GetNumberFromString(node2.Attributes['style']);
    if (smallest = largest) then begin
      perc := 1;
    end else begin
      perc := round((nr2-smallest) / (largest-smallest));
    end;

    // Create mc
    if (StringToColorEx(node2.Attributes['color']) = Null) then begin
      col := GetColorFromGradient(perc);
    end else begin
      col := StringToColorEx(node2.Attributes['color']);
    end;
    if (StringToColorEx(node2.Attributes['hicolor']) = Null) then begin
      if (hicolor = tcolor1) then begin
        hicol := getColorFromGradient(perc);
      end else begin
        hicol := hicolor;
      end;
    end else begin
      hicol := StringToColorEx(node2.Attributes['hicolor']);
    end;

    mc := TTag.Create(Self, node2, col, hicol);

    // Store reference
    mcList.push(mc);
  end;
  // Distribute the tags on the sphere
  PositionAll();

  // Add event listeners
  Self.OnMouseLeave := MouseExitHandler;
  Self.OnMouseMove := MouseMoveHandler;
  Self.OnResize := ResizeHandler;

  // Add and enable ENTER_FRAME handler
  InternalTimer.OnTimer := updateTags;
  InternalTimer.Enabled := true;
end;

procedure TTagCloud.Initialize(O: TXML);
var
  MyContextMenu : TContextMenu;
  Item : TContextMenuItem;
  I: integer;
begin
  // Settings
//NOFIX:  Self.ScaleMode := StageScaleMode.NO_SCALE;
//NOFIX:  Self.Align := StageAlign.TOP_LEFT;

  // Add context menu item
  MyContextMenu := TContextMenu.Create(Self);
  MyContextMenu.Items.Clear;
  Item := TContextMenuItem.Create(MyContextMenu);
  Item.Caption := 'WP-Cumulus by Roy Tanck and Luke Morton';
  MyContextMenu.Items.Add(Item);
  Self.PopupMenu := MyContextMenu;
  Item.OnClick := MenuItemSelectHandler;

  Init(O);
end;

procedure TTagCloud.UpdateTags(Sender: TObject);
var
  a: Number;
  b: Number;
  J: Integer;
  c: Number;
  m: Number;

  rx1: Number;
  ry1: Number;
  rz1: Number;
  rx2: Number;
  ry2: Number;
  rz2: Number;
  rx3: Number;
  ry3: Number;
  rz3: Number;

  per: Number;
begin
  m := 7;

  if (active) then begin
    a := (-Math.min( Math.max( Holder.mouseY, -250 ), 250 ) / 150 ) * tspeed;
    b := (Math.min( Math.max( Holder.mouseX, -250 ), 250 ) /150 ) * tspeed;
  end else begin
    a := lasta * 0.98;
    b := lastb * 0.98;
  end;
  lasta := a;
  lastb := b;
  // If a and b under threshold, skip motion calculations to free up the processor
  if( (abs(a) > 0.01) or (abs(b) > 0.01) ) then begin
    c := 0;
    SineCosine(a, b, c);
    // Moving the points
    for  j := 0 to mcList.Count-1 do begin
      // Multiply positions by a x-rotation matrix
      rx1 := TTag(mcList.getObject(j)).cx;
      ry1 := TTag(mcList.getObject(j)).cy * ca + TTag(mcList.getObject(j)).cz * -sa;
      rz1 := TTag(mcList.getObject(j)).cy * sa + TTag(mcList.getObject(j)).cz * ca;
      // Multiply new positions by a y-rotation matrix
      rx2 := rx1 * cb + rz1 * sb;
      ry2 := ry1;
      rz2 := rx1 * -sb + rz1 * cb;
      // Multiply new positions by a z-rotation matrix
      rx3 := rx2 * cc + ry2 * -sc;
      ry3 := rx2 * sc + ry2 * cc;
      rz3 := rz2;
      // Set arrays to new positions
      TTag(mcList.getObject(j)).cx := rx3;
      TTag(mcList.getObject(j)).cy := ry3;
      TTag(mcList.getObject(j)).cz := rz3;
      // Add perspective
      per := d / (d+rz3);
      // Setmc position, scale, alpha
      TTag(mcList.getObject(j)).X := round((rx3 * per) * m);
      TTag(mcList.getObject(j)).Y := round((ry3 * per) * m);
      TTag(mcList.getObject(j)).ScaleX := round(per * m);
      TTag(mcList.getObject(j)).ScaleY := round(per * m);
      TTag(mcList.getObject(j)).Alpha := (per/2);
    end;
    DepthSort();
  end;
end;

procedure TTagCloud.DepthSort();
var
  Current: Integer;
  I: Integer;
begin
  mcList.SortOn('cz'{, [DESCENDING | NUMERIC] });
  Current := 0;
  for I := 0 to mcList.Count-1 do begin
    Holder.SetChildIndex(TTag(mcList.getObject(i)), I);
    if (TTag(mcList.getObject(i)).Active = True) then begin
      Current := I;
    end;
  end;
  Holder.setChildIndex(TTag(mcList.getObject(current)), mcList.Count-1);
end;

destructor TTagCloud.Destroy;
begin
  InternalTimer.Enabled := False;
  InternalTimer.Free;

  mcList.Free;

  inherited Destroy;
end;

function TTagCloud.GetBackgroundColor: TColor;
begin
  Result := Color;
end;

function ComapreTag(Item1, Item2: Pointer): Integer;
begin
  if Random()<0.5 then begin
    Result := 1;
  end else begin
    Result := -1;
  end;
end;

(* See http://blog.massivecube.com/?p=9 *)
procedure TTagCloud.PositionAll();
var
  Phi: Extended;
  Theta: Extended;
  Max: Integer;
  I: Integer;
begin
  Randomize;

  Phi := 0;
  Theta := 0;
  Max := mcList.Count;

  // Mix up the list so not all a' live on the north pole
  mcList.Sort(@ComapreTag);

  // Distibute
  for I := 1 to Max do begin
    if (distr) then begin
      Phi := Math.ArcCos(-1 + (2 * I - 1) / Max);
      Theta := Sqrt(Max * System.PI) * Phi;
    end else begin
      Phi := Random() * (System.PI);
      Theta := Random() * (2 * System.PI);
    end;

    // Coordinate conversion
    TTag(mcList.getObject(I-1)).cx := Radius * Cos(Theta) * Sin(Phi);
    TTag(mcList.getObject(I-1)).cy := Radius * Sin(Theta) * Sin(Phi);
    TTag(mcList.getObject(I-1)).cz := Radius * Cos(Phi);
  end;
end;

procedure TTagCloud.menuItemSelectHandler(Sender : TObject);
var
  request : TURLRequest;
begin
  request := TURLRequest.Create( 'http://www.roytanck.com' );
  try
    NavigateToURL(request);
  finally
    request.Free;
  end;
end;

procedure TTagCloud.MouseExitHandler(Sender: TObject);
begin
  Active := False;
end;

procedure TTagCloud.MouseMoveHandler(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
	Active := True;
end;

procedure TTagCloud.ResizeHandler(Sender: TObject);
begin
  ResizeHolder();
end;

procedure TTagCloud.ResizeHolder();
var
  scale : Number;
begin
  holder.Left := round(Self.Width/2);
  holder.top := round(Self.Height/2);
  if(self.Width > self.Height) then begin
    scale := (self.Height/500);
  end else begin
    scale := (self.Width/500);
  end;
  holder.ScaleX := scale;
  holder.ScaleY := scale;
  // Scale mousetrap too
// TODO:  mousetrap_mc.width := s.stageWidth;
// TODO:  mousetrap_mc.height := s.stageHeight;
end;

procedure TTagCloud.SetBackgroundColor(const Value: TColor);
begin
  Color := Value;
end;

procedure TTagCloud.SetSpeed(const Value: Integer);
begin
  tspeed := Value / 100;
end;

procedure TTagCloud.SetTransparentMode(const Value: Boolean);
begin
  _Transparent := Value;
end;

procedure TTagCloud.SineCosine(a: Number; b: Number; c: Number);
begin
  sa := Sin(a * dtr);
  ca := Cos(a * dtr);
  sb := Sin(b * dtr);
  cb := Cos(b * dtr);
  sc := Sin(c * dtr);
  cc := Cos(c * dtr);
end;

function TTagCloud.getNumberFromString(const s: String) : Number;
var
  regexpr : TRegEx;
  match   : TMatchCollection;
  i       : integer;
  buffer  : String;
begin
  regexpr := TRegEx.Create('(\d|\.|\,)', [roCompiled, roSingleLine]);
  match := regexpr.Matches(s);
  if match.Count=0 then begin
    result := 0;
  end else begin
    buffer := '';
    for I := 0 to match.Count-1 do begin
      buffer := buffer + match.Item[i].Value;
    end;
    buffer := StringReplace(buffer, ',', '.', [rfReplaceAll]);
    result := StrToFloatDef(buffer, 0);
  end;
end;


function TTagCloud.GetTransparentMode: Boolean;
begin
  result := _Transparent;
end;

function TTagCloud.GetColorFromGradient(perc: Integer): TColor;
var
  r : Integer;
  g : Integer;
  b : Integer;
begin
  r := ( perc * ( tcolor1 SHR 16 ) ) + ( (1-perc) * ( tcolor2 SHR 16 ) );
  g := ( perc * ( (tcolor1 SHR 8) mod 256 ) ) + ( (1-perc) * ( (tcolor2 SHR 8) mod 256 ) );
  b := ( perc * ( tcolor1 mod 256 ) ) + ( (1-perc) * ( tcolor2 mod 256 ) );
  result := (r SHL 16) OR (g SHL 8) OR b ;
end;

end.
