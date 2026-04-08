const express = require('express')
const app = express()
const PORT = 3000

app.get('/products', (req, res) => {
    res.json([
        { id: 1, name: 'Laptop', price: 999 },
        { id: 2, name: 'Headphones', price: 199 },
        { id: 3, name: 'Mouse', price: 99 },
        { id: 4, name: 'Keyboard', price: 299 },
        { id: 5, name: 'Board', price: 499 }
    ])
})

app.listen(PORT, () => console.log(`E-commerce API running on port ${PORT}`))
