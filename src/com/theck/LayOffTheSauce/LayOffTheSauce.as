import com.GameInterface.DistributedValue;
import com.GameInterface.Game.Character;
import com.GameInterface.Game.CharacterBase;
import com.GameInterface.Inventory;
import com.Utils.Archive;
import mx.utils.Delegate;
import com.Utils.ID32;

class com.theck.LayOffTheSauce.LayOffTheSauce{
	
	// Version
	static var version:String = "1.0";
	
	private var m_Character:Character;
	private var m_Inventory:Inventory;
	private var AutoSauce:DistributedValue;
	private var BuffPollingInterval:Number;
	private var timeout;
	
	static var POLLING_INTERVAL_SHORT:Number = 1000; // short polling interval (used when option enabled but some other stall case is found)
	static var POLLING_INTERVAL_MEDIUM:Number = 10000; // medium polling interval (used when option is disabled)
	static var POLLING_INTERVAL_LONG:Number = 31000; // long polling interval (used when consuming sauce)
	static var HOT_SAUCE_ITEM:Number = 7863089; // Dante's Hot Sauce (item)
	static var HOT_SAUCE_BUFF:Number = 7915991; // Drank a Bottle of Hot Sauce (dmg buff)
	static var DEATH_BUFFID:Number = 9212298; // dead buff id

	public static function main(swfRoot:MovieClip):Void{
		var mod = new LayOffTheSauce(swfRoot)
		swfRoot.onLoad  = function() { mod.Load(); };
		swfRoot.onUnload  = function() { mod.Unload();};
		swfRoot.OnModuleActivated = function(config:Archive) {mod.Activate(config)};
		swfRoot.OnModuleDeactivated = function() {return mod.Deactivate()};
	}
	
    public function LayOffTheSauce(swfRoot: MovieClip){
		AutoSauce = DistributedValue.Create("AutoSauce");
	}
	
	public function Load(){
		m_Character = Character.GetClientCharacter();
		m_Inventory = new Inventory(new ID32(_global.Enums.InvType.e_Type_GC_BackpackContainer, m_Character.GetID().GetInstance()));
		com.GameInterface.UtilsBase.PrintChatText("LayOffTheSauce v" + version + " Loaded! Use '/setoption AutoSauce <true/false>' to toggle");
	}
	
	public function Unload(){
		clearInterval(BuffPollingInterval);
	}
	
	public function Activate(config:Archive){
		AutoSauce.SetValue(config.FindEntry("AutoSauce", false));
		RescheduleInterval(POLLING_INTERVAL_SHORT);
	}
	
	public function Deactivate():Archive{
		var arch:Archive = new Archive();
		arch.AddEntry("AutoSauce", AutoSauce.GetValue());
		return arch
	}
	

	// Auto Sauce Code
	
	private function FindSauceInInventory():Number {		
		for ( var i:Number = 0; i < m_Inventory.GetMaxItems(); i++ ) {
			if ( m_Inventory.GetItemAt(i).m_ACGItem.m_TemplateID0 == HOT_SAUCE_ITEM ) { 
				return i;
			};
		}
		return -1;
	}

	private function UseSauce() {
		if ( AutoSauce.GetValue() ) {
			var slotNo:Number = FindSauceInInventory();
			if ( slotNo >= 0 ) {
				Inventory(m_Inventory).UseItem(slotNo);
				//com.GameInterface.UtilsBase.PrintChatText("LayOffTheSauce: DRINK DRINK DRINK");
			}
		
			// if we were successful, no need to check for the next 30 seconds. Clear the polling interval and reschedule for ~30s later
			if ( m_Character.m_BuffList[HOT_SAUCE_BUFF] ) {
				RescheduleInterval( POLLING_INTERVAL_LONG )
			}
		}
	}
	
	private function RefreshSauceBuff() {
		// run through some logic to prevent wasting sauce 
				
		// don't use sauce if dead (not sure which of these conditionals is actually needed for death)
		// Actually observed this trigger once when running back in a lair so I suppose we'll keep it
		if ( m_Character.IsDead() || m_Character.m_BuffList[DEATH_BUFFID] || m_Character.m_InvisibleBuffList[DEATH_BUFFID] ) { return; };
		
		
		// Disable in reticule mode (inventory, alt, etc.)
		if ( ! CharacterBase.IsInReticuleMode() ) {
			RescheduleInterval(POLLING_INTERVAL_SHORT);
			return;
		}
				
		// check for existing sauce buff
		if ( m_Character.m_BuffList[HOT_SAUCE_BUFF] ) {
			// if we already have the buff, reschedule the polling to a longer interval
			RescheduleInterval(POLLING_INTERVAL_SHORT);
			return;
		}	
		
		// unused conditionals from AutoRepair - just in case we need them later
		
		//// don't use sauce if in Agartha (todo: add London, New York, Seoul?)
		//if ( m_Character.GetPlayfieldID() == 5060 ) { return; };
		
		//// check for sprinting - if "Dismounted" buff not present, don't use
		//if ( IsSprinting() ) { return; };

		//// check for Equal Footing (events, PVP) - if we see this, clear interval until next combat
		//if ( HasEqualFooting() ) { 
			//clearInterval(BuffPollingInterval);
			//return; 
		//};
		
		//// don't use sauce out of combat
		//// This happens sometimes when sprinting through mobs or in defense cases. ToggleCombat fires even though the player isn't actually in combat.
		//if ( ! m_Character.IsInCombat() ) { return;	};
		
		
		
		// if we've made it through all of these checks, use sauce
		UseSauce();
	}
	
	private function RescheduleInterval(intervalAmount:Number) {
		clearInterval(BuffPollingInterval);
		// if the option is enabled, reschedule based on the caller's request
		if ( AutoSauce.GetValue() ) {
			BuffPollingInterval = setInterval(Delegate.create(this, RefreshSauceBuff), intervalAmount);
		}
		// if it's disabled, use the medium interval (checks every 10s)
		else {
			BuffPollingInterval = setInterval(Delegate.create(this, RefreshSauceBuff), POLLING_INTERVAL_MEDIUM);
		}
	}
	
	// Other stuff related to unused conditionals
	
	//private function ToggledCombat(state:Boolean) {
		//// only check for refreshes if option is set, we're entering combat, and inventory contains pure Sauce
		//if ( AutoSauce.GetValue() && state && ( FindSauceInInventory() > 0 ) ) {
			//// run once on enter combat
			//RefreshSauceBuff();
			//// start polling 
			//RescheduleInterval(POLLING_INTERVAL_SHORT);	
		//}
		//else {
			//clearInterval(BuffPollingInterval); 
		//}
	//}
	
	//private function IsSprinting():Boolean {
		//// this checks the invisible buff list for Sprinting I through VI
		//var sprintList;
		//sprintList = [ 7481588, 7758936, 7758937, 7758938, 9114480, 9115262];
		//
		//for ( var item in sprintList ) {
			//if m_Character.m_InvisibleBuffList[sprintList[item]] {
				//return true;
			//}
		//}
		//return false;
	//}
	//
	//private function HasEqualFooting():Boolean {
		//// check for equal footing buffs, efList contains every one in the game just in case
		//var efList;
		////         Talos       ?      PVP ------------------------------------------------------------------------------PVP        ?
		//efList = [ 7512032, 7512030, 7512342, 7512343, 7512344, 7512345, 7512347, 7512348, 7512349, 7512350, 7512351, 8475143, 9358379];
		//
		//for ( var item in efList ) {
			//if m_Character.m_BuffList[efList[item]] {
				//return true;
			//}
		//}
		//return false;
	//}
	 
	
	//private function Debug(str:String) {
		//com.GameInterface.UtilsBase.PrintChatText("LOTS: " + str);
	//}
}