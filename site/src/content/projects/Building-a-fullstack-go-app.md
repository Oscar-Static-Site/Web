# Building a go app. 

After reading and getting through the go books about web apps let's go and let's go further, I wanted to apply my learnings by building something myself.

## Why go?

Having previously learned Python, I found Go's simplicity and explicitness refreshing. While it requires more manual handling, it aligns better with my preferences, allowing for a deeper understanding and precise control over the application.

## Why Postgres?

I wanted to a project that wasn't a simple hello world, that I could demonstrate the deployment of a more complex app and having more elements and not just a simple API. So I decided to add a DB, Postgres seems a suitable option, but MySQL would be equally good.

## Why htmx and Tailwindcss?

I never dabbled much in the frontend world, and it felt that this was the easiest way to achieve an app that has a nice UI and reactivity.



## Project Structure

.
├── cmd
│   ├── handlers_test.go
│   ├── handlres.go
│   ├── main.go
│   ├── templates.go
│   └── validate.go
├── docker-compose.yaml
├── Dockerfile
├── go.mod
├── go.sum
├── internal
│   └── data
│       ├── main.go
│       ├── main_test.go
│       └── testutils.go
├── Makefile
├── migrate
│   ├── 0001_create_table.sql
│   ├── comand.sh
│   └── migrationsfs.go
├── migrations
│   └── migrate.go
│   │      ├── package.json
├── package-lock.json
├── public
│   └── tailwind.css
├── README.md
├── static
│   ├── edit-form.html
│   ├── htmx.min.js
│   ├── input.css
│   ├── static.go
│   └── tailwind.css
├── tailwind.config.js
├── templates
│   ├── edit-form.html
│   ├── efs.go
│   ├── index.html
│   └── table.html
── todo

### Code Highlights:

#### All the routes for the crud operations

``` go
func serverRoutes(app *application) {
	// use embed for the static files
	assets, _ := static.Assets()
	fs := http.FileServer(http.FS(assets))
	http.Handle("/static/", http.StripPrefix("/static/", fs))
	http.HandleFunc("/", app.GetTodosHandler)
	http.HandleFunc("/health", app.Health)
	http.HandleFunc("/new-todo", app.InsertTodoHandler)
	http.HandleFunc("/delete/", app.RemoveTodoHandler)
	http.HandleFunc("/update/", app.MarkTodoDoneHandler)
	http.HandleFunc("/modify/", app.EditHandlerForm)
	http.HandleFunc("/edit/", app.EditTodoHandler)
}
```
#### Main struct to define the CRUD operations.
``` go

type TodoModel interface {
	InsertTodo(args string) error
	GetTodo() ([]Todo, error)
	RemoveTodo(id int) error
	MarkTodoAsDone(id int) error
	EditTodo(id int, task_name string) error
	SelectTodo(id int) (*Todo, error)
	GetLastInsertedTodo() (*Todo, error)
	Ping(ctx context.Context) error
}
type Todo struct {
	Id        int
	Task_name string
	Status    bool
}

type Postgres struct {
	DB *pgxpool.Pool
}

```

#### Main functions that creates the servers makes the migrations and makes sure that we set up the db properly
``` go

func main() {
	ctx := context.Context(context.Background())
	dsn := getdgburl()
	err := mg.MigrateDb(dsn)
	if err != nil {
		log.Fatal("Db is not set up properly chekc the env vars")
	}
	if err != nil {
		log.Fatal("Failed to migrate DB")
	}
	db, err := internal.NewPool(ctx, dsn)
	if err != nil {
		log.Fatal("Failed to set up DB")
	}
	app := &application{
		todos: &internal.Postgres{DB: db},
	}
	serverRoutes(app)
	err = http.ListenAndServe(":3000", nil)
	if err != nil {
		log.Fatal("Unable to start http server")
	}
	log.Println("Server running on port 3000")
}

```

## Demonstration of how the app works 

![go app](/images/todo.gif) 
