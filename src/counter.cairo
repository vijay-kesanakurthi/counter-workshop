#[derive(starknet::Event, Drop)]
#[starknet::interface]
trait ICounter<TContractState> {
    fn get_counter(ref self: TContractState) -> u32;
    fn increase_counter(ref self: TContractState);
}

#[starknet::contract]
pub mod counter_contract {
    use openzeppelin_access::ownable::OwnableComponent::InternalTrait;
    use starknet::contract_address::ContractAddress;
    use kill_switch::{IKillSwitchDispatcher, IKillSwitchDispatcherTrait};
    use openzeppelin::access::ownable::OwnableComponent;

    #[storage]
    struct Storage {
        counter: u32,
        kill_switch: ContractAddress,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;


    #[constructor]
    fn constructor(
        ref self: ContractState,
        initial_value: u32,
        kill_switch: ContractAddress,
        initial_owner: ContractAddress
    ) {
        self.ownable.initializer(initial_owner);
        self.counter.write(initial_value);
        self.kill_switch.write(kill_switch);
    }

    #[external(v0)]
    fn get_counter(ref self: ContractState) -> u32 {
        self.counter.read()
    }

    #[derive(starknet::Event, Drop)]
    struct CounterIncreased {
        value: u32
    }

    #[event]
    #[derive(starknet::Event, Drop)]
    enum Event {
        CounterIncreased: CounterIncreased,
        #[flat]
        OwnableEvent: OwnableComponent::Event
    }

    #[external(v0)]
    fn increase_counter(ref self: ContractState) {
        self.ownable.assert_only_owner();

        let kill_switch = IKillSwitchDispatcher { contract_address: self.kill_switch.read() };
        assert!(!kill_switch.is_active(), "Kill Switch is active");

        self.counter.write(self.counter.read() + 1);
        self.emit(CounterIncreased { value: self.counter.read() });
    }
}

