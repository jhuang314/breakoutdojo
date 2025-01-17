use dojo_starter::models::{Direction, Position};
use dojo_starter::models::{Vec2, Moves, DirectionsAvailable, Ball, Paddle, Brick, Score};

const BRICK_ROWS: u32 = 9;
const BRICK_COLUMNS: u32 = 5;

// define the interface
#[starknet::interface]
trait IActions<T> {
    fn start(ref self: T, game_id: u32);
    fn move(ref self: T, game_id: u32, direction: Direction);
    fn tick(ref self: T, game_id: u32);

    fn spawn(ref self: T);
    fn moveOriginal(ref self: T, direction: Direction);
}

// dojo decorator
#[dojo::contract]
pub mod actions {
    use super::{IActions, Direction, Position, next_position, next_paddle_dx, next_paddle};
    use starknet::{ContractAddress, get_caller_address};
    use dojo_starter::models::{Vec2, Moves, DirectionsAvailable, Ball, Paddle, Brick, Score};

    use dojo::model::{ModelStorage, ModelValueStorage};
    use dojo::event::EventStorage;

    #[derive(Copy, Drop, Serde)]
    #[dojo::event]
    pub struct Moved {
        #[key]
        pub player: ContractAddress,
        pub direction: Direction,
    }

    #[abi(embed_v0)]
    impl ActionsImpl of IActions<ContractState> {
        fn start(ref self: ContractState, game_id: u32) {
            // Get the default world.
            let mut world = self.world_default();

            // Get the address of the current caller, possibly the player's address.
            let player = get_caller_address();

            let new_ball = Ball {
                player,
                game_id,
                vec: Vec2 { x: 400, y: 300 },
                size: 10,
                speed: 4,
                dx: 4,
                dy: -4,
                visible: true,
            };

            let new_paddle = Paddle {
                player,
                game_id,
                vec: Vec2 { x: 360, y: 580 },
                w: 80,
                h: 10,
                speed: 8,
                dx: 0,
                visible: true,
            };

            // Write the new entities to the world.
            world.write_model(@new_ball);
            world.write_model(@new_paddle);
        }

        // Implementation of the move function for the ContractState struct.
        fn move(ref self: ContractState, game_id: u32, direction: Direction) {
            let mut world = self.world_default();

            let player = get_caller_address();

            let paddle: Paddle = world.read_model((player, game_id));

            let next_paddle = next_paddle_dx(paddle, Option::Some(direction));

            // Write the new position to the world.
            world.write_model(@next_paddle);
            // Emit an event to the world to notify about the player's move.
        //world.emit_event(@Moved { player, direction });
        }

        fn tick(ref self: ContractState, game_id: u32) {
            let mut world = self.world_default();

            let player = get_caller_address();

            let paddle: Paddle = world.read_model((player, game_id));
            let next_paddle = next_paddle(paddle);

            world.write_model(@next_paddle);
        }

        fn spawn(ref self: ContractState) {
            // Get the default world.
            let mut world = self.world_default();

            // Get the address of the current caller, possibly the player's address.
            let player = get_caller_address();

            // Retrieve the player's current position from the world.
            let position: Position = world.read_model(player);

            // Update the world state with the new data.

            // 1. Move the player's position 10 units in both the x and y direction.
            let new_position = Position {
                player, vec: Vec2 { x: position.vec.x + 10, y: position.vec.y + 10 },
            };

            // Write the new position to the world.
            world.write_model(@new_position);

            // 2. Set the player's remaining moves to 100.
            let moves = Moves {
                player, remaining: 100, last_direction: Option::None, can_move: true,
            };

            // Write the new moves to the world.
            world.write_model(@moves);
        }

        // Implementation of the moveOriginal function for the ContractState struct.
        fn moveOriginal(ref self: ContractState, direction: Direction) {
            // Get the address of the current caller, possibly the player's address.

            let mut world = self.world_default();

            let player = get_caller_address();

            // Retrieve the player's current position and moves data from the world.
            let position: Position = world.read_model(player);
            let mut moves: Moves = world.read_model(player);
            // if player hasn't spawn, read returns model default values. This leads to sub overflow
            // afterwards.
            // Plus it's generally considered as a good pratice to fast-return on matching
            // conditions.
            if !moves.can_move {
                return;
            }

            // Deduct one from the player's remaining moves.
            moves.remaining -= 1;

            // Update the last direction the player moved in.
            moves.last_direction = Option::Some(direction);

            // Calculate the player's next position based on the provided direction.
            let next = next_position(position, moves.last_direction);

            // Write the new position to the world.
            world.write_model(@next);

            // Write the new moves to the world.
            world.write_model(@moves);

            // Emit an event to the world to notify about the player's move.
            world.emit_event(@Moved { player, direction });
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Use the default namespace "dojo_starter". This function is handy since the ByteArray
        /// can't be const.
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"dojo_starter")
        }
    }
}

// Define function like this:
fn next_position(mut position: Position, direction: Option<Direction>) -> Position {
    match direction {
        Option::None => { return position; },
        Option::Some(d) => match d {
            Direction::Left => { position.vec.x -= 1; },
            Direction::Right => { position.vec.x += 1; },
            Direction::Up => { position.vec.y -= 1; },
            Direction::Down => { position.vec.y += 1; },
        },
    };
    position
}


fn next_paddle_dx(mut paddle: Paddle, direction: Option<Direction>) -> Paddle {
    match direction {
        Option::None => { return paddle; },
        Option::Some(d) => match d {
            Direction::Left => { paddle.dx = -paddle.speed; },
            Direction::Right => { paddle.dx = paddle.speed; },
            Direction::Up => { return paddle; },
            Direction::Down => { return paddle; },
        },
    };
    paddle
}

fn next_paddle(mut paddle: Paddle) -> Paddle {
    paddle.vec.x += paddle.dx;
    paddle
}

