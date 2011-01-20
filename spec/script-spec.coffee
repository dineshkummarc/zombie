require "./helpers"
{ vows: vows, assert: assert, zombie: zombie, brains: brains } = require("vows")

brains.get "/script/context", (req, res)-> res.send """
  <script>var foo = 1;</script>
  <script>foo = foo + 1;</script>
  <script>document.title = foo;</script>
  """

brains.get "/script/order", (req, res)-> res.send """
  <html>
    <head>
      <title>Zero</title>
      <script src="/script/order.js"></script>
    </head>
    <body>
      <script>
      document.title = document.title + "Two";</script>
    </body>
  </html>
  """
brains.get "/script/order.js", (req, res)-> res.send "document.title = document.title + 'One'";

brains.get "/dead", (req, res)-> res.send """
  <html>
    <head>
      <script src="/jquery.js"></script>
    </head>
    <body>
      <script>
        $(function() { document.title = "The Dead" });
      </script>
    </body>
  </html>
  """

brains.get "/script/write", (req, res)-> res.send """
  <html>
    <head>
      <script>document.write(unescape(\'%3Cscript src="/jquery.js"%3E%3C/script%3E\'));</script>
    </head>
    <body>
      <script>
        $(function() { document.title = "Script document.write" });
      </script>
    </body>
  </html>
  """

brains.get "/script/append", (req, res)-> res.send """
  <html>
    <head>
      <script>
        var s = document.createElement('script'); s.type = 'text/javascript'; s.async = true;
        s.src = '/jquery.js';
        (document.getElementsByTagName('head')[0] || document.getElementsByTagName('body')[0]).appendChild(s);
      </script>
    </head>
    <body>
      <script>
        $(function() { document.title = "Script appendChild" });
      </script>
    </body>
  </html>
  """

brains.get "/living", (req, res)-> res.send """
  <html>
    <head>
      <script src="/jquery.js"></script>
      <script src="/sammy.js"></script>
      <script src="/app.js"></script>
    </head>
    <body>
      <div id="main">
        <a href="/dead">Kill</a>
        <form action="#/dead" method="post">
          <label>Email <input type="text" name="email"></label>
          <label>Password <input type="password" name="password"></label>
          <button>Sign Me Up</button>
        </form>
      </div>
      <div class="now">Walking Aimlessly</div>
    </body>
  </html>
  """
brains.get "/app.js", (req, res)-> res.send """
  Sammy("#main", function(app) {
    app.get("#/", function(context) {
      document.title = "The Living";
    });
    app.get("#/dead", function(context) {
      context.swap("The Living Dead");
    });
    app.post("#/dead", function(context) {
      document.title = "Signed up";
    });
  });
  $(function() { Sammy("#main").run("#/") });
  """

brains.get "/script/jqtemplates-span", (req, res)-> res.send """
  <html>
    <head>
      <title>Foo</title>
      <script src="/jquery.js"></script>
      <script src="/jquery.tmpl.js"></script>
    </head>
    <body>
      <span id="movieTemplate" style="display:none">
          <li><b>${Name}</b> (${ReleaseYear})</li>
      </span>
      <script>
        var movies = [
            { Name: "Night of the Living Dead", ReleaseYear: "1968" },
            { Name: "Dawn of the Dead", ReleaseYear: "1978" },
            { Name: "Shaun of the Dead", ReleaseYear: "2004" }
        ];

        // Render the template with the movies data and insert
        // the rendered HTML under the "movieList" element
        $( "#movieTemplate" ).tmpl( movies )
            .appendTo( "#movieList" );
      </script>
      <div id="movieList">
      </div>
    </body>
  </html>
  """


brains.get "/script/jqtemplates-script", (req, res)-> res.send """
  <html>
    <head>
      <title>Foo</title>
      <script src="/jquery.js"></script>
      <script src="/jquery.tmpl.js"></script>
    </head>
    <body>
      <script id="movieTemplate" type="text/x-jquery-tmpl">
          <li><b>${Name}</b> (${ReleaseYear})</li>
      </script>
      <script>
        var movies = [
            { Name: "Night of the Living Dead", ReleaseYear: "1968" },
            { Name: "Dawn of the Dead", ReleaseYear: "1978" },
            { Name: "Shaun of the Dead", ReleaseYear: "2004" }
        ];

        // Render the template with the movies data and insert
        // the rendered HTML under the "movieList" element
        $( "#movieTemplate" ).tmpl( movies )
            .appendTo( "#movieList" );
      </script>
      <div id="movieList">
      </div>
    </body>
  </html>
  """


vows.describe("Scripts").addBatch(
  "script context":
    zombie.wants "http://localhost:3003/script/context"
      "should be shared by all scripts": (browser)-> assert.equal browser.text("title"), "2"

  "script order":
    zombie.wants "http://localhost:3003/script/order"
      "should run scripts in order regardless of source": (browser)-> assert.equal browser.text("title"), "ZeroOneTwo"

  "adding script using document.write":
    zombie.wants "http://localhost:3003/script/write"
      "should run script": (browser)-> assert.equal browser.document.title, "Script document.write"
  "adding script using appendChild":
    zombie.wants "http://localhost:3003/script/append"
      "should run script": (browser)-> assert.equal browser.document.title, "Script appendChild"

  "jquery template test":
    zombie.wants "http://localhost:3003/script/jqtemplates-span"
      "should not eval jqtmpl script tag contents": (browser)-> assert.equal browser.querySelector('#movieList>li>b').innerHTML, 'Night of the Living Dead'

  # THIS WILL THROW AN ERROR AND HANG THE TESTS
  "jquery template test 2":
    zombie.wants "http://localhost:3003/script/jqtemplates-script"
      "should not eval jqtmpl script tag contents": (browser)-> assert.equal browser.querySelector('#movieList>li>b').innerHTML, 'Night of the Living Dead'

  "run without scripts":
    topic: ->
      browser = new zombie.Browser(runScripts: false)
      browser.wants "http://localhost:3003/script/order", @callback
    "should not run scripts": (browser)-> assert.equal browser.document.title, "Zero"

  "run app":
    zombie.wants "http://localhost:3003/living"
      "should execute route": (browser)-> assert.equal browser.document.title, "The Living"
      "should change location": (browser)-> assert.equal browser.location, "http://localhost:3003/living#/"
      "move around":
        topic: (browser)->
          browser.visit browser.location.href + "dead", @callback
        "should execute route": (browser)-> assert.equal browser.text("#main"), "The Living Dead"
        "should change location": (browser)-> assert.equal browser.location.href, "http://localhost:3003/living#/dead"

  "live events":
    zombie.wants "http://localhost:3003/living"
      topic: (browser)->
        browser.fill("Email", "armbiter@zombies").fill("Password", "br41nz").
          pressButton "Sign Me Up", @callback
      "should change location": (browser)-> assert.equal browser.location, "http://localhost:3003/living#/"
      "should process event": (browser)-> assert.equal browser.document.title, "Signed up"

  "evaluate":
    zombie.wants "http://localhost:3003/living"
      topic: (browser)->
        browser.evaluate "document.title"
      "should evaluate in context and return value": (title)-> assert.equal title, "The Living"

).export(module)
