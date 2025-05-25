const express = require('express');
const session = require('express-session');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware setup
app.use(express.urlencoded({ extended: true }));
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Session config
app.use(session({
  secret: 'supersecretkey123',
  resave: false,
  saveUninitialized: false,
  cookie: {
    httpOnly: true,
    maxAge: 7 * 24 * 60 * 60 * 1000 // 7 days
  }
}));

// Helpers
const getUsers = () => {
  const usersPath = path.join(__dirname, 'data', 'users.json');
  return fs.existsSync(usersPath)
    ? JSON.parse(fs.readFileSync(usersPath, 'utf-8'))
    : [];
};

const saveUsers = (users) => {
  const usersPath = path.join(__dirname, 'data', 'users.json');
  fs.writeFileSync(usersPath, JSON.stringify(users, null, 2));
};

// Signup route
app.post('/signup', (req, res) => {
  const { username, password } = req.body;
  const users = getUsers();

  if (users.find(u => u.username === username)) {
    return res.send('Username already taken!');
  }

  users.push({
    username,
    password,
    createdAt: Date.now(),
    paid: false
  });

  saveUsers(users);
  res.redirect('/login.html');
});

// Login route
app.post('/login', (req, res) => {
  const { username, password } = req.body;
  const users = getUsers();
  const user = users.find(u => u.username === username && u.password === password);

  if (!user) return res.send('Invalid credentials.');

  req.session.loggedIn = true;
  req.session.username = user.username;
  req.session.createdAt = user.createdAt;
  req.session.paid = user.paid;

  res.redirect(user.paid ? '/dashboard' : '/payment.html');
});

// Simulate payment
app.post('/pay', (req, res) => {
  if (!req.session.loggedIn) return res.redirect('/login.html');

  const users = getUsers();
  const index = users.findIndex(u => u.username === req.session.username);

  if (index !== -1) {
    users[index].paid = true;
    users[index].createdAt = Date.now();

    saveUsers(users);

    req.session.paid = true;
    req.session.createdAt = users[index].createdAt;

    res.redirect('/dashboard');
  } else {
    res.send('User not found.');
  }
});

// Middleware to protect routes
const checkAuth = (req, res, next) => {
  if (req.session.loggedIn && req.session.paid) {
    return next();
  }
  res.redirect(req.session.loggedIn ? '/payment.html' : '/login.html');
};

// Protected dashboard
app.get('/dashboard', checkAuth, (req, res) => {
  res.sendFile(path.join(__dirname, 'protected', 'dashboard.html'));
});

// Dashboard data API
app.get('/dashboard-data', (req, res) => {
  if (!req.session.loggedIn || !req.session.username) {
    return res.status(401).send('Not logged in');
  }

  const users = getUsers();
  const user = users.find(u => u.username === req.session.username);

  if (!user) return res.status(404).send('User not found');

  const start = new Date(user.createdAt); // using createdAt from signup/pay
  const now = new Date();
  const diffTime = Math.abs(now - start);
  const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

  if (diffDays >= 0) {
    return res.status(403).send('Subscription expired');
  }

  res.json({
    username: user.username,
    daysLeft: 7 - diffDays
  });
});

// Logout route
app.get('/logout', (req, res) => {
  req.session.destroy(() => res.redirect('/login.html'));
});

// Serve payment.html with session check
app.get('/payment.html', (req, res) => {
  if (!req.session.loggedIn) {
    return res.redirect('/login.html');
  }
  res.sendFile(path.join(__dirname, 'protected', 'payment.html'));
});

// Start the server
app.listen(PORT, () => {
  console.log(`Server running at http://localhost:${PORT}`);
});
      
