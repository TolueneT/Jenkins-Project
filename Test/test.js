const request = require("supertest");
const server = require("../src/index");

describe("GET /", () => {
	it("should return Hello World", (done) => {
		request(server).get("/").expect(200, "Hello World\n", done);
	});
});
