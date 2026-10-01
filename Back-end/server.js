require('dotenv').config();

const http = require('http');
const express = require('express');
const cors = require('cors');
const rateLimit = require('express-rate-limit'); // 👈 1. Importamos a biblioteca do escudo

const { sequelize } = require('./models');
const { initSocket } = require('./realtime/socket_server');
const healthRoutes = require('./routes/health');
const usuarioRoutes = require('./routes/usuario');
const authRoutes = require('./routes/auth');
const grupoRoutes = require('./routes/grupo/grupo');
const caronaRoutes = require('./routes/carona/carona');
const carroRoutes = require('./routes/carro/carro');

const app = express();

app.set('trust proxy', 1);

// 2. Criamos o Escudo Global (Evita lentidão e queda da API inteira)
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // Janela de 15 minutos
  max: 150, // Limite de 150 requisições por IP
  message: { error: 'Muitas requisições deste IP. Tente novamente mais tarde.' }
});

app.use(cors({
  origin: '*', 
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization', 'ngrok-skip-browser-warning']
}));

// 3. Criamos o Escudo de Autenticação (Evita força bruta no login)
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // Janela de 15 minutos
  max: 10, // Limite de 10 tentativas de login/cadastro por IP
  message: { error: 'Muitas tentativas de login. Bloqueado por 15 minutos por segurança.' }
});

app.use(cors());
app.use(express.json());

// 4. Aplicamos o escudo global no aplicativo todo, ANTES de abrir as rotas
app.use(globalLimiter);

app.use(healthRoutes);
app.use(usuarioRoutes);

// 5. Aplicamos o escudo mais forte APENAS nas rotas de login/cadastro
app.use(authLimiter, authRoutes); 

app.use(grupoRoutes);
app.use(caronaRoutes);
app.use(carroRoutes);

// Servidor HTTP compartilhado entre Express e Socket.IO.
const httpServer = http.createServer(app);
const io = initSocket(httpServer);
// Disponibiliza o io para os controllers (ex: broadcast de mensagem nova).
app.set('io', io);

const port = Number(process.env.PORT) || 3000;

sequelize.authenticate()
  .then(() => {
    console.log(`Banco conectado: ${process.env.DB_NAME}`);
    httpServer.listen(port, () => {
      console.log(`API rodando em http://localhost:${port}`);
    });
  })
  .catch((err) => {
    console.error('Falha ao conectar no banco:', err.message);
    process.exit(1);
  });