# Cumulus

![Main](screenshots/main.png)

## About

This is a Delphi port of the infamous "WP-Cumulus" WordPress plugin, originally an ActionScript flash project written by Roy Tanck.

It allows you to load your data from an XML document, displaying contained tags and/or categories by placing them on a rotating sphere, and allowing these tags to be clicked.


### API

#### Methods

| Names | Description
| --- | ---
| `Create()` | Creates and initializes a `TTagCloud` instance
| `Initialize()` | Initializes the `TTagCloud` instance with XML data

#### Properties

| Names | Description
| --- | ---
| `Width` | Width of the Flash tag cloud
| `Height` | Height of the Flash tag cloud
| `TagColor` | Color of the tags
| `TagColor2` |
| `HighColor` |
| `BackgroundColor` | Background color
| `TransparentMode` | Use transparent mode
| `RotationSpeed` | Rotation speed
| `EvenlyDistributedTags` | Distribute tags evenly on sphere
| `DisplayMode` | Whether to display tags, categories, or both

#### Events

| Names | Description
| --- | ---
| `OnNavigateToURL` | Occurs when the user clicks a tag that has a URL


## Usage

```delphi
procedure TfrmCumulus.FormShow(Sender: TObject);
var
  MyXML : IXMLDocument;
begin
  TagCloud := TTagCloud.Create(Self);
  TagCloud.Parent := Self;
  TagCloud.OnNavigateToURL := NavigateToURLHandler;

  TagCloud.Align := alClient;

  TagCloud.TagsColor := $ffffff;
  TagCloud.BackgroundColor := $333333;
  TagCloud.TransparentMode := False;
  TagCloud.RotationSpeed := 100;
  TagCloud.EvenlyDistributedTags := True;
  TagCloud.DisplayMode := dmTags;

  try
    MyXML := LoadXMLDocument('tagcloud.xml');
    TagCloud.Initialize(MyXML);
  except
    ShowMessage('Failed while attempting to load XML file.');
  end;
end;
```

## Caveat

Having entities defined in XML files should be avoided. Since while they are being loaded, they will cause an exception to be raised of class type `EDOMParseError`, with the message `Reference to undefined entity xyz`.


## Contributing

Please take a look at the [contributing](CONTRIBUTING.md) guidelines if you're interested in helping!


## License

Cumulus is licensed under the MIT License - see the [LICENSE-DELPHI](LICENSE-DELPHI.md) file for details.
