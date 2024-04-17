
drop procedure if Exists PROC_BALANCE_SHEET;
DELIMITER $$
CREATE  PROCEDURE `PROC_BALANCE_SHEET`( P_ENTRY_DATE_FROM TEXT,
										P_ENTRY_DATE_TO TEXT,
										P_YEAR TEXT,
										P_COMPANY_ID INT )
BEGIN

				Declare IncomeAmount  		Decimal default 0;
				Declare CostAmount    		Decimal default 0;
				Declare ExpenseAmount 		Decimal default 0;
				Declare AssetAmount   		Decimal default 0;
				Declare LiabilityAmount 	Decimal default 0;
				Declare EquityAmount 		Decimal default 0;
				Declare GrossProfit 		Decimal default 0;
				Declare EquityType          Decimal default 0;
				Declare TOTAL_L_E			Decimal Default 0;
			
				select 
						SUM(A.Income)   ,
						SUM(A.Cost)     ,
						Sum(A.Expense)  ,
						Sum(A.Asset)    ,
						SUM(A.Liability),
						Sum(A.Equity)
				into 
						IncomeAmount,
						CostAmount,
						ExpenseAmount,
						AssetAmount,
						LiabilityAmount,
						EquityAmount
				from (
						select 
								Case when A.Account_ID = 1 then A.Balance else 0 end as Income,
								Case When A.Account_ID = 2 then A.Balance else 0 end as Cost,
								Case When A.Account_Id = 5 then A.Balance else 0 end as Expense,
								Case When A.Account_Id = 3 then A.Balance else 0 end as Asset,
								Case When A.Account_Id = 4 then A.Balance else 0 end as Liability,
								Case when A.Account_Id = 6 then A.Balance else 0 end as Equity
						from (
									select 
											SUM(A.Balance) as Balance ,
											A.AccountId	   			  ,
											B.ACC_ID	   			  ,
											D.Accounts_Name			  ,
											C.Account_Id 
									from 
											Daily_Account_Balance A 
									inner join 
											Accounts_Id B 
									on 
											A.AccountId = B.id	
									inner join 
											Account_Type C 
									ON 
											B.Account_Type_Id = C.id	
									inner join 
											Accounts D 
									on 
											C.Account_Id = D.id
									where 
											case 
												when 
													P_ENTRY_DATE_TO <> "" then 
													A.ENTRYDATE <= Convert(P_ENTRY_DATE_TO,Date)
													else true
											end
									and 
											case 
												when 
													P_COMPANY_ID <> "" then 
													B.Company_Id = P_COMPANY_ID
													else true
											end
									group by 
											A.AccountId,
											B.ACC_ID,
											D.Accounts_Name,
											C.Account_Id 
									order by
											C.Account_Id
							 ) as A 
					) as A;
					
					
					-- ===================== TOTAL GROSS =====================
                  
					SELECT IFNULL(IncomeAmount, 0) - IFNULL(CostAmount, 0) - IFNULL(ExpenseAmount, 0) INTO GrossProfit;
                  
					-- ===================== TOTAL GROSS =====================
					
					
					-- ===================== EQUITY TYPE =====================
                  
					SELECT 
							E.ID 
					INTO 
							EquityType
					FROM 
							Accounts_Id D,
						    Account_Type E
					WHERE 
						   CASE
								WHEN P_COMPANY_ID <> "" THEN D.COMPANY_ID = P_COMPANY_ID
								ELSE TRUE
						   END 
					   AND D.Account_Type_Id = E.Id
					   AND E.Account_Id = 6 
    				   ORDER BY E.Id DESC LIMIT 1;
                  
					-- ===================== EQUITY TYPE =====================
					
					-- ===================== TOTAL LIABILITY AND EQUITY =====================
                  
					SELECT IFNULL(LiabilityAmount, 0) + IFNULL(EquityAmount, 0) + IFNULL(GrossProfit, 0) INTO TOTAL_L_E;

					-- ===================== TOTAL LIABILITY AND EQUITY =====================
					
					
					
					SELECT 
							  ACCOUNT,
							  ACCOUNT_TYPE, 
							  ID,
							  ACC_ID, 
							  DESCRIPTION, 
							  AMOUNT AS AMOUNT,
							  COUNT(*) OVER() AS TOTAL_ROWS
					from (
					SELECT 
							G.ACCOUNT,
							G.ACCOUNT_TYPE_ID,
							G.ACCOUNT_TYPE, 
                            G.ID,
							G.ACC_ID, 
							G.DESCRIPTION, 
							SUM(G.AMOUNT) AS AMOUNT
					from (
	
					select 
							
							D.Accounts_Name 		as Account,
							C.id 					as Account_Type_Id,
							C.Account_Type_Name 	as Account_Type,
							B.id,
							B.ACC_ID,
							B.Description,
							SUM(A.Balance) 			as Amount
					from 
							Daily_Account_Balance A 
					Right join 
							Accounts_Id B 
					on 
							B.id = A.AccountId
					inner join 
							Account_Type C 
					ON 
							C.id = B.Account_Type_Id 
					inner join 
							Accounts D  
					ON 
							D.id = C.Account_Id
					where 
							case 
								when 
									P_COMPANY_ID <> "" then B.COMPANY_ID = P_COMPANY_ID
									else true 
								end 
					And 
							case 
								when 
									P_ENTRY_DATE_TO <> "" then A.ENTRYDATE <= P_ENTRY_DATE_TO
									else true 
								end 
					AND 
							(D.id =3 OR D.id = 4 OR D.id = 6)
					
									
					group by 
							D.Accounts_Name,
							C.id,
							C.Account_Type_Name,
							B.id,
							B.ACC_ID,
							B.Description
							
					UNION ALL
                                        
                    SELECT 
							"EQUITY" 			  AS ACCOUNT,
							 EquityType 		  AS ACCOUNT_TYPE_ID,
							"EQUITY" 			  AS ACCOUNT_TYPE,
							"-1"				  AS ID,
							"-1" 				  AS ACC_ID,
							"NET PROFIT" 		  AS DESCRIPTION,
							GrossProfit 		  AS AMOUNT
					) G
					group by 
							G.ACCOUNT,
							G.ACCOUNT_TYPE_ID,
							G.ACCOUNT_TYPE, 
                            G.ID,
							G.ACC_ID, 
							G.DESCRIPTION
					with RollUp 
					HAVING 
							(
							  Account 	   is not null And
							  ACCOUNT_TYPE is not null And  
							  ID           is not null And
							  ACC_ID	   is not null And 
							  DESCRIPTION  is not null And 
							  AMOUNT 	   is not null
								
							)
					OR 
								  
							(
							  Account 	   is not null AND
							  ACCOUNT_TYPE is null And  
							  ID           is null And
							  ACC_ID	   is null And 
							  DESCRIPTION  is null And 
							  AMOUNT 	   is not null
							)
							
					union all 
					
					SELECT 
								"" AS ACCOUNT,
                        "99999999" AS ACCOUNT_TYPE_ID,
						"99999999" AS ACCOUNT_TYPE,
                                "" AS ID,
                                "" AS ACC_ID,
      "Total Liability and Equity" AS ACCOUNT,
						 TOTAL_L_E AS AMOUNT ) as V;
					
	
	
    
END $$
DELIMITER ;